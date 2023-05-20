# LocationSimulator

Use for simulating GPS location (longitude, latitude, altitude) data. Support scalable for test workload.

Source code is available on [Github](https://github.com/ohhi-vn/location_simulator)

Package for using on [Hex.pm](https://hex.pm/packages/location_simulator)

## Achitecture

The library has 3 main part:

1. Supervisor. Lib uses `PartitionSupervisor` for creating worker from config
2. Worker. Generating GPS with user config
3. Callback module. This is defined by user to handle event from worker

### Api call flow

```mermaid
sequenceDiagram
    participant CallbackMod
    participant Worker
    participant Api
    participant Supervisor

    Api->>Supervisor: Start with workers from config
    Supervisor->>Worker: Start GPS generator
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
    {:location_simulator, "~> 0.3.0"}
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
      direciton: :random,
      altitude: 100,
      altitude_way: :up,
      callback: MyCallbackModule
    }

LocationSimulator.start(config)
```

Simulator support directions:

:north, :south, :east, :west, :north_east, :north_west, :south_east, :south_west

If :direction is missed or equal :random, simulator will random a direction for each worker.

## Example

Start library in Elixir's shell:

```bash
mix deps.get

iex -S mix

iex(1)> LocationSimulator.start()
```

For writing callback module please go to `LocationSimulator.Event` document.

[Code demo generate GPX file from library](https://github.com/ohhi-vn/location_simulator/tree/main/example/generate_gpx)
