import Config
import Dotenvy

# Load .env (plus an optional env-specific override) for local development.
# Real OS environment variables always win over the files, which is what you
# want in a release. Missing files are simply skipped.
env_files = Enum.filter([".env", ".env.#{config_env()}"], &File.exists?/1)
source!(env_files ++ [System.get_env()])

telegram_token = env!("TELEGRAM_BOT_TOKEN", :string, nil)

config :lead_bot,
  telegram_token: telegram_token,
  openrouter_api_key: env!("OPENROUTER_API_KEY", :string, nil),
  openrouter_model: env!("OPENROUTER_MODEL", :string, "nvidia/nemotron-3-ultra-550b-a55b:free"),
  openrouter_fallback_model: env!("OPENROUTER_FALLBACK_MODEL", :string, nil)

# ExGram also reads the token from its own application env.
if is_binary(telegram_token) and telegram_token != "" do
  config :ex_gram, token: telegram_token
end
