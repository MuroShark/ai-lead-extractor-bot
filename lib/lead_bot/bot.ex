defmodule LeadBot.Bot do
  @moduledoc """
  Telegram bot entry point (ExGram, long polling).

  Handles incoming updates, coordinates message deduplication via Rust NIF fingerprints,
  delegates text extraction to `LeadBot.Extractor`, and sends the rendered HTML lead cards.
  """

  @bot :lead_bot

  use ExGram.Bot, name: @bot, setup_commands: true

  require Logger
  alias LeadBot.{Card, Dedup, Extractor, Native}

  # Hard cap on end-to-end extraction so a slow/hung model never blocks a reply.
  @deadline_ms 90_000
  # Telegram's "typing" status lasts ~5s, so we refresh it while we wait.
  @typing_interval_ms 4_000

  # Declared so ExGram dispatches them as atoms ({:command, :start, msg}).
  # Without this, "/start" arrives as {:command, "start", msg} (a string) and
  # falls through to the catch-all.
  command("start", description: "Показать приветствие и как пользоваться")
  command("help", description: "Показать приветствие и как пользоваться")

  def bot, do: @bot

  def handle({:command, :start, _msg}, context), do: answer(context, start_message())
  def handle({:command, :help, _msg}, context), do: answer(context, start_message())

  def handle({:text, text, msg}, context) do
    fingerprint = Native.fingerprint(text)
    key = {msg.chat.id, fingerprint}
    Logger.info("incoming text len=#{String.length(text)} fp=#{String.slice(fingerprint, 0, 12)}")

    case Dedup.check_and_mark(key) do
      :duplicate ->
        Logger.info("duplicate message, skipping fp=#{String.slice(fingerprint, 0, 12)}")
        _ = ExGram.send_message(msg.chat.id, "↩️ Это сообщение я уже недавно обрабатывал.")
        :ok

      :new ->
        process_new(text, msg, key)
    end

    context
  end

  def handle(_update, _context), do: :ok

  defp process_new(text, msg, key) do
    task = Task.async(fn -> Extractor.extract(text) end)

    case await_with_typing(task, msg.chat.id, 0) do
      {:ok, extraction} ->
        extraction |> Card.render() |> Enum.each(&send_html(msg.chat.id, &1))

      {:error, reason} ->
        Logger.warning("extraction failed: #{inspect(reason)}")
        # Let the user retry — don't hold the fingerprint after a failure.
        Dedup.forget(key)
        send_html(msg.chat.id, error_message(reason))
    end
  end

  # Keep the "typing" status alive while waiting, and enforce the hard deadline.
  defp await_with_typing(task, chat_id, elapsed) do
    _ = ExGram.send_chat_action(chat_id, "typing")

    case Task.yield(task, @typing_interval_ms) do
      {:ok, result} ->
        result

      {:exit, reason} ->
        {:error, {:crash, reason}}

      nil ->
        if elapsed + @typing_interval_ms >= @deadline_ms do
          _ = Task.shutdown(task, :brutal_kill)
          {:error, :timeout}
        else
          await_with_typing(task, chat_id, elapsed + @typing_interval_ms)
        end
    end
  end

  defp send_html(chat_id, text) do
    _ = ExGram.send_message(chat_id, text, parse_mode: "HTML")
    :ok
  end

  defp error_message(:no_api_key),
    do: "⚙️ Не задан OPENROUTER_API_KEY — не могу обратиться к модели."

  defp error_message({:http, status, _retry_ms}) when status in [408, 429, 500, 502, 503, 504],
    do: "⏳ Модель сейчас перегружена или недоступна. Попробуй ещё раз через минуту."

  defp error_message({:http, status}) when status in [408, 429, 500, 502, 503, 504],
    do: "⏳ Модель сейчас перегружена или недоступна. Попробуй ещё раз через минуту."

  defp error_message(reason) when reason in [:all_models_failed, :transport],
    do: "⏳ Модель сейчас недоступна (сеть или лимит). Попробуй ещё раз через минуту."

  defp error_message(:timeout),
    do: "⌛ Модель слишком долго не отвечает. Попробуй ещё раз чуть позже."

  defp error_message(reason) when reason in [:bad_json, :bad_response],
    do: "🤔 Модель вернула неразборчивый ответ. Попробуй переформулировать сообщение."

  defp error_message(_),
    do: "⚠️ Что-то пошло не так при разборе сообщения. Попробуй ещё раз."

  defp start_message do
    "Привет! Пришли мне сырое сообщение клиента (из чата, почты, формы) — " <>
      "я верну аккуратную карточку лида: кто клиент, контакт, что хочет, срочность."
  end
end
