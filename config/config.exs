import Config

# ExGram defaults to the Tesla adapter (needs tesla+hackney). We use its Req
# adapter instead — req is already an ExGram dependency, so no extra HTTP stack.
config :ex_gram, adapter: ExGram.Adapter.Req

config :lead_bot,
  openrouter_base_url: "https://openrouter.ai/api/v1",
  request_timeout_ms: 30_000
