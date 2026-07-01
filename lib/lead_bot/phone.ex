defmodule LeadBot.Phone do
  @moduledoc """
  Best-effort normalization of Russian phone numbers to `+7XXXXXXXXXX`.

  Falls back to the original string for anything it doesn't recognize, so we
  never lose or mangle a contact we're unsure about.
  """

  @spec normalize(String.t() | nil) :: String.t() | nil
  def normalize(nil), do: nil

  def normalize(raw) when is_binary(raw) do
    digits = String.replace(raw, ~r/\D/, "")

    case digits do
      <<"8", rest::binary-size(10)>> -> "+7" <> rest
      <<"7", rest::binary-size(10)>> -> "+7" <> rest
      <<rest::binary-size(10)>> -> "+7" <> rest
      _ -> raw
    end
  end
end
