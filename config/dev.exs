import Config

# Configures Elixir's Logger
config :logger, :console,
  level: :info,
  format: "$time $metadata[$level] $message\n"

config :location_simulator, :default_config,
  event: 1,
  worker: 1,
  interval: 100,
  random_range: 10,
  callback:  LocationSimulator.LoggerEvent
