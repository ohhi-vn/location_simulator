import Config

# Configures Elixir's Logger
config :logger, :console,
  level: :info,
  format: "$time $metadata[$level] $message\n"

config :location_simulator, :default_config,
  event: 5,
  worker: 1,
  interval: 100,
  random_range: 10,
  altitude: 50,
  altitude_way: :up,
  callback:  LocationSimulator.LoggerEvent
