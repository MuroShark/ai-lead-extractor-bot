defmodule LeadBot.NativeTest do
  use ExUnit.Case, async: true

  alias LeadBot.Native

  describe "normalize/1" do
    test "collapses whitespace and lowercases" do
      assert Native.normalize("  Hello   WORLD  ") == "hello world"
    end

    test "applies Unicode NFKC normalization" do
      # Full-width digits normalize to ASCII.
      assert Native.normalize("１２３") == "123"
    end
  end

  describe "fingerprint/1" do
    test "is stable across casing and whitespace" do
      a = Native.fingerprint("Здравствуйте,   это  АННА")
      b = Native.fingerprint("здравствуйте, это анна")
      assert a == b
    end

    test "differs for different content" do
      refute Native.fingerprint("хочу CRM") == Native.fingerprint("хочу сайт")
    end
  end
end
