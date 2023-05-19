import Config

# Configures Elixir's Logger
config :logger, :console,
  level: :debug,
  format: "$time $metadata[$level] $message\n"

config :location_simulator, :default_config,
  event: 1,
  worker: 1,
  interval: 1,
  random_range: 1,
  callback:  LocationSimulator.LoggerEvent
