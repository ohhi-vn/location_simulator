[comment]: # (guides/getting_started.md)

# Getting Started

## Installation

Add `location_simulator` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:location_simulator, "~> 1.0}
  ]
end
```

Then run `mix deps.get`.

## Quick start

Start the simulator with default config — fires GPS events using the built-in `LoggerEvent` callback:

```elixir
LocationSimulator.start()
```

You'll see output like:

```
[info] Start location worker: 1, timestamp: 1700000000
[info] 1, new GPS: %{lat: 60.0, lon: 87.0, ele: 0, timestamp: ...}
[info] 1 is stopped, time: 0s, success: 1, failed: 0, error: 0
```

## With a pipeline (recommended)

Define a pipeline module that declares your simulation structure:

```elixir
defmodule MyApp.Simulation do
  use LocationSimulator.Pipeline

  source :synthetic, direction: :north_east, elevation: 100

  plug LocationSimulator.Plug.Callback, callback: MyApp.GpsHandler
end

LocationSimulator.start(MyApp.Simulation, worker: 3, event: 100, interval: 1_000)
```

## With a callback module

```elixir
defmodule MyApp.GpsHandler do
  @behaviour LocationSimulator.Event

  @impl true
  def start(config, _state), do: {:ok, config}

  @impl true
  def event(config, %{gps: gps}) do
    IO.inspect(gps, label: "GPS")
    {:ok, config}
  end

  @impl true
  def stop(config, state) do
    IO.puts("Done: #{state.success} ok, #{state.failed} failed")
    {:ok, config}
  end
end
```

## Legacy API

If you prefer a flat config map:

```elixir
LocationSimulator.start(%{
  worker: 3,
  event: 100,
  interval: 1_000,
  direction: :north,
  callback: MyApp.GpsHandler
})
```

## Runtime config reference

| Key | Type / Values | Default |
|---|---|---|
| `:worker` | `pos_integer()` | `1` |
| `:event` | `pos_integer() \| :infinity` | `1` |
| `:interval` | `pos_integer() \| :gpx_time` | `100` ms |
| `:random_range` | `non_neg_integer()` | `10` ms |
| `:direction` | direction atom | `:random` |
| `:elevation` | `integer()` | `0` |
| `:elevation_way` | `:up \| :down \| :no_up_down` | `:no_up_down` |
| `:callback` | module implementing `Event` | `LocationSimulator.LoggerEvent` |
| `:group_id` | `any()` | `nil` |
| `:gpx_file` | glob string | `nil` |
| `:started_gps` | `{lat, lon, ele}` | `nil` |
