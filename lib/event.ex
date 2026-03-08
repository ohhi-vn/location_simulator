defmodule LocationSimulator.Event do
  @moduledoc """
  Callback behaviour that bridges the worker and your application code.

  Implement all three callbacks in a module and pass it as `:callback` in
  the simulator config.

  ## Callback lifecycle
  start/2  →  event/2  →  event/2  →  …  →  stop/2
  ## `state` map keys

  | Key           | Type                        | Available in        |
  |---------------|-----------------------------|---------------------|
  | `:start_time` | `non_neg_integer()` (unix s)| all callbacks       |
  | `:success`    | `non_neg_integer()`         | `event/2`, `stop/2` |
  | `:failed`     | `non_neg_integer()`         | `event/2`, `stop/2` |
  | `:error`      | `non_neg_integer()`         | `event/2`, `stop/2` |
  | `:gps`        | `t:gps_point/0`             | `event/2`, `stop/2` |
  | `:stop_time`  | `non_neg_integer()` (unix s)| `stop/2` only       |

  ## GPS point map (`:gps` key)

  | Key          | Type      | Description                                |
  |--------------|-----------|--------------------------------------------|
  | `:lat`       | `float()` | Latitude in decimal degrees                |
  | `:lon`       | `float()` | Longitude in decimal degrees               |
  | `:ele`       | `float()` | Elevation in metres                        |
  | `:timestamp` | `integer()` | Milliseconds elapsed since worker start  |
  | `:time`      | `NaiveDateTime.t() \| nil` | Original GPX timestamp (GPX workers only) |

  ## Minimal example

      defmodule MyApp.GpsHandler do
        @behaviour LocationSimulator.Event

        @impl true
        def start(config, _state), do: {:ok, config}

        @impl true
        def event(config, %{gps: gps} = _state) do
          MyApp.Tracker.push(gps.lat, gps.lon)
          {:ok, config}
        end

        @impl true
        def stop(config, state) do
          MyApp.Tracker.finish(state.success, state.failed)
          {:ok, config}
        end
      end
  """

  @typedoc "GPS point map delivered to `event/2` and `stop/2` via `state.gps`."
  @type gps_point :: %{
          required(:lat) => float(),
          required(:lon) => float(),
          required(:ele) => float(),
          required(:timestamp) => non_neg_integer(),
          optional(:time) => NaiveDateTime.t() | nil
        }

  @doc """
  Called once when the worker starts, before any GPS events.

  Return `{:ok, config}` with an optionally updated config map.
  Return `{:error, reason}` to abort the worker before it generates any data.
  """
  @callback start(config :: map(), state :: map()) ::
              {:ok, config :: map()} | {:error, reason :: any()}

  @doc """
  Called for each generated GPS point.

  * `{:ok, config}` – success; worker continues with the returned config.
  * `{:error, reason}` – increments `:failed` counter; worker continues.
  * `{:stop, reason}` – worker stops gracefully after firing `stop/2`.
  """
  @callback event(config :: map(), state :: map()) ::
              {:ok, config :: map()} | {:error, reason :: any()} | {:stop, reason :: any()}

  @doc """
  Called once after the last GPS event (or when a stop is requested).

  `:stop_time` is available in `state` here.
  """
  @callback stop(config :: map(), state :: map()) ::
              {:ok, config :: map()} | {:error, reason :: any()}
end
