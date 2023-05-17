import Config

config :location_simulator, :default_config,
  event: 10,
  worker: 3,
  interval: 100,
  random_range: 10,
  callback:  LocationSimulator.LoggerEvent
