defmodule LeadBot.ExtractionTest do
  use ExUnit.Case, async: true

  alias LeadBot.{Card, Extractor, Phone}

  describe "Phone.normalize/1" do
    test "8-prefixed RU number -> +7" do
      assert Phone.normalize("8 999 123 45 67") == "+79991234567"
    end

    test "already +7 stays +7" do
      assert Phone.normalize("+7 (900) 555-66-77") == "+79005556677"
    end

    test "unrecognized input is returned as-is" do
      assert Phone.normalize("звоните в офис") == "звоните в офис"
    end

    test "nil passes through" do
      assert Phone.normalize(nil) == nil
    end
  end

  describe "Extractor.decode/1" do
    test "parses JSON wrapped in code fences and prose" do
      raw = ~s(Вот результат:\n```json\n{"is_lead": true, "leads": []}\n```\nготово)
      assert {:ok, %{"is_lead" => true}} = Extractor.decode(raw)
    end

    test "returns :bad_json for non-JSON" do
      assert {:error, :bad_json} = Extractor.decode("извините, не понял")
    end
  end

  describe "Extractor.normalize/1" do
    test "fills defaults and drops is_lead when leads are empty" do
      normalized = Extractor.normalize(%{"is_lead" => true, "leads" => []})
      assert normalized["is_lead"] == false
      assert normalized["leads"] == []
    end

    test "normalizes lead shape" do
      normalized =
        Extractor.normalize(%{
          "is_lead" => true,
          "leads" => [%{"name" => "Анна", "request" => "CRM"}]
        })

      assert [lead] = normalized["leads"]
      assert lead["name"] == "Анна"
      assert lead["category"] == "другое"
      assert lead["contact"] == %{"phone" => nil, "email" => nil, "telegram" => nil}
    end
  end

  describe "Card.render/1" do
    test "one message per lead for a multi-lead extraction" do
      extraction =
        Extractor.normalize(%{
          "is_lead" => true,
          "leads" => [
            %{"name" => "Пётр", "request" => "CRM", "category" => "CRM"},
            %{
              "name" => "Маша",
              "request" => "бот",
              "category" => "бот",
              "contact" => %{"phone" => "89005556677"}
            }
          ]
        })

      cards = Card.render(extraction)
      assert length(cards) == 2
      assert Enum.at(cards, 1) =~ "+79005556677"
    end

    test "not-a-lead renders a single rejection message" do
      extraction = Extractor.normalize(%{"is_lead" => false, "spam_reason" => "благодарность"})
      assert [message] = Card.render(extraction)
      assert message =~ "Не похоже на заявку"
    end

    test "appends an injection note when detected" do
      extraction =
        Extractor.normalize(%{
          "is_lead" => true,
          "injection_detected" => true,
          "leads" => [%{"request" => "автоматизация"}]
        })

      cards = Card.render(extraction)
      assert List.last(cards) =~ "проигнорировал"
    end

    test "escapes HTML in user-provided values" do
      extraction =
        Extractor.normalize(%{"is_lead" => true, "leads" => [%{"request" => "<b>hack</b>"}]})

      assert [card] = Card.render(extraction)
      assert card =~ "&lt;b&gt;hack&lt;/b&gt;"
    end
  end
end
