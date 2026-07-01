defmodule LeadBot do
  @moduledoc """
  AI lead extractor Telegram bot.

  Pipeline:

      Telegram (ExGram, long polling)
        -> Rust NIF normalize/fingerprint (dedup, see `LeadBot.Native`)
        -> OpenRouter free-model extraction
        -> formatted lead card reply

  Elixir/OTP owns concurrency, supervision and resilience; the CPU-bound text
  normalization and hashing live in a small Rust NIF.
  """
end
