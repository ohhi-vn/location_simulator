import Config

# Configures Elixir's Logger
config :logger, :console,
  level: :info,
  format: "$time $metadata[$level] $message\n"

# overide default config for dev.
config :location_simulator, :default_config,
  event: 1000,
  worker: 1,
  interval: 10,
  random_range: 10,
  elevation: 50,
  elevation_way: :up,
  callback:  LocationSimulator.LoggerEvent
