import Config

config :location_simulator, :test_info,
  # support: :http, :websocket
  protocol: :http,
  counter: 100,
  worker: 3,
  game: 1,
  interval: 100,
  random_range: 50,
  url: "http://localhost:8080/api/game"
  #url: "ws://localhost:8080/api/socket/websocket"
