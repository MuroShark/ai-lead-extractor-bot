defmodule LeadBot.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [LeadBot.Dedup, ExGram | bot_children()]

    opts = [strategy: :one_for_one, name: LeadBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Only start the Telegram bot when a token is configured, so `iex -S mix`
  # and tooling don't crash-loop on a fresh checkout without an .env file.
  defp bot_children do
    case Application.get_env(:lead_bot, :telegram_token) do
      token when is_binary(token) and token != "" ->
        [{LeadBot.Bot, [method: :polling, token: token]}]

      _ ->
        Logger.warning(
          "TELEGRAM_BOT_TOKEN is not set — starting without the Telegram bot. " <>
            "Copy .env.example to .env and fill it in."
        )

        []
    end
  end
end
