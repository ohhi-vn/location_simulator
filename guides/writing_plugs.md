[comment]: # (guides/writing_plugs.md)

# Writing Plugs

A plug is a module that implements the `LocationSimulator.Plug` behaviour. Plugs transform the pipeline map for each GPS event.

## The behaviour

```elixir
@callback init(opts :: term()) :: term()
@callback call(pipeline :: map(), opts :: term()) :: map()
```

- `init/1` — Called once when the pipeline is assembled. Transforms the user-declared options into the compiled opts passed to `call/2`.
- `call/2` — Called for every GPS event. Receives the pipeline map and opts; returns an updated pipeline.

## Writing your first plug

```elixir
defmodule MyApp.SpeedLimitPlug do
  @behaviour LocationSimulator.Plug

  @impl true
  def init(opts), do: Keyword.get(opts, :max_speed, 100)

  @impl true
  def call(pipeline, max_speed) do
    %{config: config, gps: gps} = pipeline

    if Map.get(gps, :speed, 0) > max_speed do
      Logger.warning("Speed #{gps.speed} exceeds limit #{max_speed}")
    end

    pipeline
  end
end
```

## Using a custom plug in a pipeline

```elixir
defmodule MyApp.Simulation do
  use LocationSimulator.Pipeline

  source :synthetic, direction: :north

  plug MyApp.SpeedLimitPlug, opts: [max_speed: 80]
  plug LocationSimulator.Plug.Callback, callback: MyApp.Handler
end
```

## Halting the pipeline

Set `halted: true` on the pipeline to stop further processing. The worker will fire `callback.stop/2` and exit.

```elixir
defmodule MyApp.MaxEventPlug do
  @behaviour LocationSimulator.Plug

  @impl true
  def init(opts), do: Keyword.fetch!(opts, :max_events)

  @impl true
  def call(pipeline, max_events) do
    events_so_far = pipeline.state.success + pipeline.state.failed

    if events_so_far >= max_events do
      %{pipeline | halted: true}
    else
      pipeline
    end
  end
end
```

## Modifying config

Plugs can update `pipeline.config` to pass data to downstream plugs:

```elixir
defmodule MyApp.GeoFencePlug do
  @behaviour LocationSimulator.Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(pipeline, _opts) do
    %{lat: lat, lon: lon} = pipeline.gps

    in_zone = lat > 20.0 and lat < 22.0 and lon > 105.0 and lon < 107.0
    config = Map.put(pipeline.config, :in_hanoi, in_zone)

    %{pipeline | config: config}
  end
end
```

## Pipeline assigns

Use `assigns` for plug-to-plug communication without modifying config:

```elixir
defmodule MyApp.AccumulatorPlug do
  @behaviour LocationSimulator.Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(pipeline, _opts) do
    prev = Map.get(pipeline.assigns, :total_distance, 0.0)
    # calculate distance from last_gps to current gps...
    %{pipeline | assigns: Map.put(pipeline.assigns, :total_distance, prev + delta)}
  end
end
```

## Built-in plugs reference

| Plug | Purpose | When to use |
|---|---|---|
| `LocationSimulator.Plug.SyntheticGps` | Generates next synthetic GPS point | Synthetic sources (auto-injected) |
| `LocationSimulator.Plug.GpxReplay` | Replays GPX track points | GPX sources (auto-injected) |
| `LocationSimulator.Plug.Callback` | Dispatches events to user callback | Always needed |
| `LocationSimulator.Plug.Sleep` | Sleeps between events | Optional, for custom timing |
