defmodule LeadBot.Native do
  @moduledoc """
  Rust NIF bindings (Rustler).

  Keeps the CPU-bound text work out of the BEAM: Unicode normalization and a
  stable fingerprint used to detect duplicate incoming messages.

  The function bodies below are stubs replaced by the loaded NIF; if the native
  library fails to load they raise `:nif_not_loaded`.
  """

  use Rustler, otp_app: :lead_bot, crate: "leadbot_native"

  @doc "Unicode-normalize (NFKC), lowercase and collapse whitespace."
  @spec normalize(String.t()) :: String.t()
  def normalize(_text), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Stable SHA-256 hex fingerprint of the normalized text, for dedup."
  @spec fingerprint(String.t()) :: String.t()
  def fingerprint(_text), do: :erlang.nif_error(:nif_not_loaded)
end
