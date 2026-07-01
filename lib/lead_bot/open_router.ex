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
        {:ok, %{status: 200, body: body}} ->
          extract_content(body)

        {:ok, %{status: status, body: b}} ->
          Logger.warning("OpenRouter HTTP #{status}: #{String.slice(inspect(b), 0, 300)}")
          {:error, {:http, status}}

        {:error, exception} ->
          Logger.warning("OpenRouter transport error: #{inspect(exception)}")
          {:error, :transport}
      end
    end
  end

  defp extract_content(%{"choices" => [%{"message" => %{"content" => content}} | _]})
       when is_binary(content),
       do: {:ok, content}

  defp extract_content(body) do
    Logger.warning("OpenRouter unexpected body: #{String.slice(inspect(body), 0, 300)}")
    {:error, :bad_response}
  end

  defp api_key do
    case Application.get_env(:lead_bot, :openrouter_api_key) do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :no_api_key}
    end
  end
end
