defmodule LeadBot.ResilienceTest do
  use ExUnit.Case, async: true

  alias LeadBot.{Dedup, Extractor}

  # Stub OpenRouter clients (stateless, keyed on the requested model)

  defmodule BadThenGoodClient do
    def chat(_messages, opts) do
      case Keyword.fetch!(opts, :model) do
        "bad" -> {:ok, "извините, тут нет json"}
        "good" -> {:ok, ~s({"is_lead": true, "leads": [{"request": "CRM"}]})}
      end
    end
  end

  defmodule TransientThenBackupClient do
    def chat(_messages, opts) do
      case Keyword.fetch!(opts, :model) do
        "flaky" -> {:error, {:http, 503}}
        "backup" -> {:ok, ~s({"is_lead": true, "leads": [{"request": "сайт"}]})}
      end
    end
  end

  defmodule DownClient do
    def chat(_messages, _opts), do: {:error, :transport}
  end

  defmodule FatalFirstClient do
    def chat(_messages, opts) do
      case Keyword.fetch!(opts, :model) do
        "nokey" -> {:error, :no_api_key}
        "good" -> {:ok, ~s({"is_lead": true, "leads": [{"request": "x"}]})}
      end
    end
  end

  describe "Extractor model fallback" do
    test "falls back to the next model when the first returns bad JSON" do
      assert {:ok, %{"is_lead" => true}} =
               Extractor.extract("...",
                 client: BadThenGoodClient,
                 models: ["bad", "good"],
                 backoff_ms: 0
               )
    end

    test "retries transient errors then falls back to the backup model" do
      assert {:ok, %{"is_lead" => true}} =
               Extractor.extract("...",
                 client: TransientThenBackupClient,
                 models: ["flaky", "backup"],
                 max_retries: 2,
                 backoff_ms: 0
               )
    end

    test "returns the last error when every model fails" do
      assert {:error, :transport} =
               Extractor.extract("...",
                 client: DownClient,
                 models: ["a", "b"],
                 backoff_ms: 0
               )
    end

    test "a missing API key is fatal and does not try further models" do
      assert {:error, :no_api_key} =
               Extractor.extract("...",
                 client: FatalFirstClient,
                 models: ["nokey", "good"],
                 backoff_ms: 0
               )
    end
  end

  describe "Dedup" do
    test "first sighting is :new, repeat within window is :duplicate" do
      key = {:erlang.unique_integer(), "fp"}
      assert Dedup.check_and_mark(key) == :new
      assert Dedup.check_and_mark(key) == :duplicate
    end

    test "forgetting a key lets it be processed again" do
      key = {:erlang.unique_integer(), "fp"}
      assert Dedup.check_and_mark(key) == :new
      assert Dedup.forget(key) == :ok
      assert Dedup.check_and_mark(key) == :new
    end

    test "different keys are independent" do
      k1 = {:erlang.unique_integer(), "a"}
      k2 = {:erlang.unique_integer(), "b"}
      assert Dedup.check_and_mark(k1) == :new
      assert Dedup.check_and_mark(k2) == :new
    end
  end
end
