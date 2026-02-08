import Config

config :job_hunting_ex,
  openrouter_api_key: System.get_env("OPENROUTER_API_KEY") || raise("Openrouter api key missing.")
