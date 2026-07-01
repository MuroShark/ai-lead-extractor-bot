defmodule LeadBot.Card do
  @moduledoc """
  Renders an extraction result into one or more Telegram messages (HTML).

  One message per lead (so two заявки arrive as two forwardable cards), an
  optional trailing note when a prompt-injection attempt was detected, and a
  friendly message when the text isn't a lead. All dynamic values are escaped.
  """

  alias LeadBot.Phone

  @spec render(map()) :: [String.t()]
  def render(%{"leads" => leads} = ex) when is_list(leads) and leads != [] do
    multi = length(leads) > 1

    leads
    |> Enum.with_index(1)
    |> Enum.map(fn {lead, idx} -> lead_card(lead, idx, multi) end)
    |> maybe_add_injection_note(ex)
  end

  def render(%{"is_lead" => false} = ex), do: [not_lead(ex)]
  def render(_), do: ["🤔 Не смог распознать заявку. Попробуй переформулировать сообщение."]

  defp not_lead(ex) do
    reason = ex["spam_reason"] || "не вижу конкретного запроса"
    "🚫 <b>Не похоже на заявку</b>\n#{esc(reason)}"
  end

  defp lead_card(lead, idx, multi) do
    header = if multi, do: "🧾 <b>Лид #{idx}</b>\n", else: ""

    header <>
      "👤 #{who(lead)}\n" <>
      "📞 #{contacts(lead)}\n" <>
      "🎯 #{esc(lead["request"])} <i>(#{esc(lead["category"])})</i>\n" <>
      "🔥 Срочность: <b>#{esc(lead["urgency"])}</b>#{urgency_reason(lead)}"
  end

  defp who(lead) do
    name = present(lead["name"])
    company = present(lead["company"])

    cond do
      name && company -> "#{esc(name)}, «#{esc(company)}»"
      name -> esc(name)
      company -> "«#{esc(company)}»"
      true -> "<i>имя не указано</i>"
    end
  end

  defp contacts(lead) do
    contact = lead["contact"] || %{}

    [
      normalize_phone(contact["phone"]),
      present(contact["email"]),
      present(contact["telegram"])
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&esc/1)
    |> case do
      [] -> "<i>контакт не указан</i>"
      parts -> Enum.join(parts, " · ")
    end
  end

  defp normalize_phone(phone) do
    case present(phone) do
      nil -> nil
      value -> Phone.normalize(value)
    end
  end

  defp urgency_reason(lead) do
    case present(lead["urgency_reason"]) do
      nil -> ""
      reason -> " — #{esc(reason)}"
    end
  end

  defp maybe_add_injection_note(cards, %{"injection_detected" => true}) do
    cards ++
      [
        "⚠️ <i>В сообщении была попытка задать боту служебные инструкции — " <>
          "я её проигнорировал и разобрал сообщение по фактам.</i>"
      ]
  end

  defp maybe_add_injection_note(cards, _), do: cards

  defp present(nil), do: nil

  defp present(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: value)

  defp present(_), do: nil

  defp esc(nil), do: ""

  defp esc(value) when is_binary(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp esc(value), do: esc(to_string(value))
end
