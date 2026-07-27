defmodule LocationSimulator do
  @moduledoc """
  Entry-point API for the LocationSimulator library.

  ## With a pipeline module (recommended)

      defmodule MyApp.Tracker do
        use LocationSimulator.Pipeline

        source :synthetic, direction: :north, elevation: 50

        plug LocationSimulator.Plug.Callback, callback: MyApp.GpsHandler
      end

      LocationSimulator.start(MyApp.Tracker, %{worker: 3, event: 100, interval: 1_000})

  ## With a plain config map (legacy)

      LocationSimulator.start(%{
        worker:       3,
        event:        100,
        interval:     1_000,
        random_range: 200,
        direction:    :north,
        elevation:    50,
        callback:     MyApp.GpsHandler
      })
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

  @doc """
  Starts workers with a pipeline module and runtime config.

  The pipeline module defines the GPS source and the plug chain.
  The config map supplies runtime parameters (worker count, event count, etc.).
  """
  @spec start(module(), map()) :: :ok
  def start(pipeline_mod, runtime_config) when is_atom(pipeline_mod) and is_map(runtime_config) do
    runtime_config
    |> Map.put(:pipeline, pipeline_mod)
    |> build_worker_specs()
    |> Sup.start_simulator()
  end

  @doc """
  Starts workers using a plain config map (legacy API).

  See the module doc for supported config keys.
  """
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
  """
  @spec stop(group_id :: any()) :: :ok
  def stop(group_id) do
    Registry.dispatch(LocationSimulator.Registry, group_id, fn entries ->
      Logger.debug("Stopping #{length(entries)} workers in group #{inspect(group_id)}")

      for {pid, id} <- entries do
        Logger.debug("Sending stop cmd for #{inspect(id)} (#{inspect(pid)})")
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

  defp fetch(key, default) do
    Keyword.get(@app_config, key, default)
  end

  defp build_worker_specs(%{pipeline: _mod} = config) do
    build_specs(config.worker, config, [])
  end

  defp build_worker_specs(%{gpx_file: glob} = config) do
    files = Path.wildcard(glob)
    if files == [], do: raise("No GPX files matched: #{glob}")
    build_gpx_specs(config.worker, config, files, files, [])
  end

  defp build_worker_specs(config) do
    build_specs(config.worker, config, [])
  end

  defp build_specs(0, _config, acc), do: acc

  defp build_specs(n, config, acc) do
    build_specs(n - 1, config, [{LocationSimulator.Worker, Map.put(config, :id, n)} | acc])
  end

  defp build_gpx_specs(0, _config, _cur, _all, acc), do: acc

  defp build_gpx_specs(n, config, [], all, acc),
    do: build_gpx_specs(n, config, all, all, acc)

  defp build_gpx_specs(n, config, [file | rest], all, acc) do
    spec = {LocationSimulator.Worker, config |> Map.put(:id, n) |> Map.put(:gpx_file, file)}
    build_gpx_specs(n - 1, config, rest, all, [spec | acc])
  end
end
