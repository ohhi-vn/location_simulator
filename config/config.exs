import Config

# Default config for demo.
config :location_simulator, :default_config,
  event: 100,
  worker: 3,
  interval: 100,
  random_range: 10,
  callback:  LocationSimulator.LoggerEvent

# Add dev/prod config, overwrite if config is existed.
import_config "#{config_env()}.exs"
