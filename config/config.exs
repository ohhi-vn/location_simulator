import Config

config :location_simulator, :default_config,
  event: 1,
  worker: 1,
  interval: 100,
  random_range: 10,
  mod:  LocationSimulator.LoggerEvent
