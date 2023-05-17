# LocationSimulator

Use for simulating location(longitude, latitude) data. Support scalable for test workload.

## Achitecture

The library has 3 main part:

1. Supervisor. Lib uses DynamicSupervisor for creating worker from config
2. Worker. Generating GPS with user config
3. Callback module. This is defined by user to handle event from worker

### Api call flow

```mermaid
sequenceDiagram
    participant CallbackMod
    participant Worker
    participant Api
    participant Sup

    Api->>Sup: Start with workers from config
    Sup->>Worker: Start GPS generator
    Worker->>CallbackMod: call start event
    Worker->>CallbackMod: call gps event
    Worker->>CallbackMod: call stop event
```

*(for in local you need install extension to view flow)*

## Installation

Library can be installed
by adding `location_simulator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:location_simulator, "~> 0.1.1"}
  ]
end
```

If you need to modify source please go to [Github](https://github.com/ohhi-vn/location_simulator) and clone repo.

## Guide

Start LocationSimulator with default config:

```elixir
LocationSimulator.start()
```

With default config simulator will print to Logger with default config

Start with your callback & config:

```elixir
config =
    %{
      worker: 3,
      event: 100,
      interval: 1000,
      random_range: 0,
      callback: MyCallbackModule
    }

LocationSimulator.start(config)
```

For writing callback module please go to `callback_event` document.
