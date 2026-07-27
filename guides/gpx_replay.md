[comment]: # (guides/gpx_replay.md)

# GPX Replay

Replay real GPS tracks from GPX files instead of generating synthetic data.

## Quick start

```elixir
defmodule MyApp.TrackReplay do
  use LocationSimulator.Pipeline

  source :gpx, gpx_file: "tracks/*.gpx"

  plug LocationSimulator.Plug.Callback, callback: MyApp.Handler
end

LocationSimulator.start(MyApp.TrackReplay, worker: 3, interval: :gpx_time)
```

## Source options

```elixir
source :gpx, gpx_file: "data/**/*.gpx"
```

| Option | Required | Description |
|---|---|---|
| `gpx_file` | yes | Glob pattern matching GPX files |
| `started_gps` | no | `{lat, lon, ele}` to override first point |

## Interval modes

### `:gpx_time` (recommended for realistic replay)

Sleeps for the exact time delta between consecutive track points, preserving the original timing.

### Fixed integer (for faster replay)

```elixir
LocationSimulator.start(MyApp.TrackReplay, worker: 1, interval: 500)
```

Each point is emitted 500ms apart, regardless of the original timestamps.

## Multiple files

When the glob matches multiple files, workers are assigned files in order, cycling through if there are more workers than files.

```
tracks/
├── morning.gpx    → Worker 1
├── afternoon.gpx  → Worker 2
└── evening.gpx    → Worker 3
```

With 5 workers and 3 files: Worker 4 gets `morning.gpx`, Worker 5 gets `afternoon.gpx`.

## GPX point structure

Each replayed point has the following keys:

```elixir
%{
  lat: 21.0278,           # float — latitude
  lon: 105.8342,          # float — longitude
  ele: 10.5,              # float — elevation in metres
  timestamp: 1700000000,  # integer — ms since worker start
  time: ~N[2024-01-01 12:00:00]  # NaiveDateTime — original GPX timestamp
}
```

## Handling GPX without elevation

If a GPX track point lacks an `<ele>` element, the elevation defaults to `0`.

## Custom interval logic

Combine with your own plug for custom timing:

```elixir
defmodule MyApp.PacingPlug do
  @behaviour LocationSimulator.Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(pipeline, _opts) do
    # Apply random jitter to original GPX timing
    sleep = Map.get(pipeline.assigns, :sleep_ms, 1000)
    jitter = floor(sleep * 0.1)
    Process.sleep(sleep + Enum.random(0..jitter))
    pipeline
  end
end
```

## Legacy API

For a flat config map approach without a pipeline module:

```elixir
LocationSimulator.start(%{
  worker: 3,
  interval: :gpx_time,
  gpx_file: "data/*.gpx",
  callback: MyApp.Handler
})
```
