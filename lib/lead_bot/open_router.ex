defmodule LeadBot.OpenRouter do
  @moduledoc """
  Thin OpenRouter chat-completions client (OpenAI-compatible API).

  Single attempt with a hard receive timeout — retries / fallback model live in
  `LeadBot.Extractor` and later phases. Never raises: returns a tagged tuple.
  """

  require Logger

  @spec chat([map()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def chat(messages, opts \\ []) do
    with {:ok, api_key} <- api_key() do
      base = Application.get_env(:lead_bot, :openrouter_base_url, "https://openrouter.ai/api/v1")
      model = Keyword.get(opts, :model, Application.get_env(:lead_bot, :openrouter_model))
      timeout = Application.get_env(:lead_bot, :request_timeout_ms, 30_000)

      body = %{
        model: model,
        temperature: Keyword.get(opts, :temperature, 0.1),
        messages: messages
      }

      req =
        Req.new(
          base_url: base,
          receive_timeout: timeout,
          retry: false,
          headers: [
            {"authorization", "Bearer " <> api_key},
            {"x-title", "AI Lead Extractor Bot"}
          ]
        )

      case Req.post(req, url: "/chat/completions", json: body) do
        {:ok, %{status: 200, body: %{"choices" => _} = b}} ->
          extract_content(b)

        # OpenRouter may return a provider error either as a non-200 status or,
        # confusingly, as HTTP 200 with an {"error": {"code": ...}} body.
        {:ok, %{status: status, body: b, headers: headers}} ->
          handle_error_response(status, b, headers)

        {:error, exception} ->
          Logger.warning("OpenRouter transport error: #{inspect(exception)}")
          {:error, :transport}
      end
    end
  end

  defp extract_content(%{"choices" => [%{"message" => %{"content" => content}} | _]})
       when is_binary(content),
       do: {:ok, content}

  defp extract_content(_body), do: {:error, :bad_response}

  # Normalize any error shape to `{:http, code, retry_after_ms}` so the retry
  # layer can back off correctly (honouring Retry-After when the provider sends
  # it). `code` prefers the provider's error code over the HTTP status.
  defp handle_error_response(status, body, headers) do
    code = provider_error_code(body) || status
    retry_ms = retry_after_ms(headers, body)

    Logger.warning(
      "OpenRouter error status=#{status} code=#{code} retry_after=#{inspect(retry_ms)}: " <>
        String.slice(inspect(body), 0, 300)
    )

    {:error, {:http, code, retry_ms}}
  end

  defp provider_error_code(%{"error" => %{"code" => code}}) when is_integer(code), do: code
  defp provider_error_code(_), do: nil

  defp retry_after_ms(headers, body) do
    raw =
      header_value(headers, "retry-after") ||
        get_in(body, ["error", "metadata", "headers", "Retry-After"])

    parse_seconds_ms(raw)
  end

  # Req normalizes response headers to a map of lowercase keys -> list of values.
  defp header_value(headers, key) do
    case headers do
      %{^key => [value | _]} -> value
      _ -> nil
    end
  end

  defp parse_seconds_ms(nil), do: nil

  defp parse_seconds_ms(value) do
    case Integer.parse(to_string(value)) do
      {seconds, _} when seconds >= 0 -> seconds * 1000
      _ -> nil
    end
  end

  defp api_key do
    case Application.get_env(:lead_bot, :openrouter_api_key) do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :no_api_key}
    end
  end
end
