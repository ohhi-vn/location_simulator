defmodule LocationSimulator do
  @moduledoc """
  Entry-point API for the LocationSimulator library.

  ## Quick start

      iex> LocationSimulator.start()

  ## Custom config

      iex> LocationSimulator.start(%{
      ...>   worker:       3,
      ...>   event:        100,
      ...>   interval:     1_000,
      ...>   random_range: 200,
      ...>   direction:    :north,
      ...>   elevation:    50,
      ...>   elevation_way: :up,
      ...>   callback:     MyApp.GpsHandler
      ...> })

  ## Config keys

  | Key             | Type / Values                          | Default                         |
  |-----------------|----------------------------------------|---------------------------------|
  | `:worker`       | `pos_integer()`                        | `1`                             |
  | `:event`        | `pos_integer() \| :infinity`           | `1`                             |
  | `:interval`     | `pos_integer() \| :gpx_time`           | `100` ms                        |
  | `:random_range` | `non_neg_integer()`                    | `10` ms extra jitter            |
  | `:direction`    | see `t:direction/0`                    | `:random`                       |
  | `:elevation`    | `integer()` (metres)                   | `0`                             |
  | `:elevation_way`| `:up \| :down \| :no_up_down`          | `:no_up_down`                   |
  | `:callback`     | module implementing `Event` behaviour  | `LocationSimulator.LoggerEvent` |
  | `:group_id`     | `any()`                                | `nil` (no group)                |
  | `:gpx_file`     | glob string e.g. `"tracks/*.gpx"`      | `nil` (synthetic GPS)           |
  | `:started_gps`  | `{lat, lon, ele}` floats               | `nil` (random start)            |

  `:id` is reserved and set automatically per worker.
  Any additional keys are forwarded unchanged to your callback module.
  """

  require Logger

  alias LocationSimulator.DynamicSupervisor, as: Sup

  @app_config Application.compile_env(:location_simulator, :default_config, %{})

  @type direction ::
          :north
          | :south
          | :east
          | :west
          | :north_east
          | :north_west
          | :south_east
          | :south_west
          | :random

  # ── Public API ─────────────────────────────────────────────────────────────

  @doc "Starts workers using `config`.  See the module doc for key reference."
  @spec start(map()) :: :ok
  def start(config) when is_map(config) do
    config
    |> build_worker_specs()
    |> Sup.start_simulator()
  end

  @doc "Starts one worker with the default / application config."
  @spec start() :: :ok
  def start do
    default_config() |> build_worker_specs() |> Sup.start_simulator()
  end

  @doc """
  Stops all workers that belong to `group_id`.

  Workers must have been started with a matching `:group_id` in their config.
  """
  @spec stop(group_id :: any()) :: :ok
  def stop(group_id) do
    Registry.dispatch(LocationSimulator.Registry, group_id, fn entries ->
      Logger.debug("Stopping #{length(entries)} workers in group #{inspect(group_id)}")

      for {pid, id} <- entries do
        Logger.debug("Sending stop cmd for #{inspect id} (#{inspect pid})")
        send(pid, {:stop_worker, id})
      end
    end)
  end

  @doc "Returns the merged default config (application config overrides built-in defaults)."
  @spec default_config() :: map()
  def default_config do
    %{
      worker: fetch(:worker, 1),
      event: fetch(:event, 1),
      interval: fetch(:interval, 100),
      random_range: fetch(:random_range, 10),
      direction: fetch(:direction, :random),
      elevation: fetch(:elevation, 0),
      elevation_way: fetch(:elevation_way, :no_up_down),
      callback: fetch(:callback, LocationSimulator.LoggerEvent)
    }
  end

  # ── Private ────────────────────────────────────────────────────────────────

  # Reads a key from the application config with a fallback default.
  defp fetch(key, default) do
    Keyword.get(@app_config, key, default)
  end

  # Dispatch to GPX or synthetic worker builder.
  @spec build_worker_specs(map()) :: [{module(), map()}]
  defp build_worker_specs(%{gpx_file: glob} = config) do
    files = Path.wildcard(glob)
    if files == [], do: raise("No GPX files matched: #{glob}")

    build_gpx_specs(config.worker, config, files, files, [])
  end

  defp build_worker_specs(config) do
    build_specs(config.worker, config, [])
  end

  # Build specs for synthetic workers (tail-recursive).
  defp build_specs(0, _config, acc), do: acc

  defp build_specs(n, config, acc) do
    build_specs(n - 1, config, [{LocationSimulator.Worker, Map.put(config, :id, n)} | acc])
  end

  # Build specs for GPX workers, cycling through available files (tail-recursive).
  defp build_gpx_specs(0, _config, _cur, _all, acc), do: acc

  defp build_gpx_specs(n, config, [], all, acc),
    do: build_gpx_specs(n, config, all, all, acc)

  defp build_gpx_specs(n, config, [file | rest], all, acc) do
    spec = {LocationSimulator.WorkerGpx, config |> Map.put(:id, n) |> Map.put(:gpx_file, file)}
    build_gpx_specs(n - 1, config, rest, all, [spec | acc])
  end
end
