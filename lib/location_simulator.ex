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

  alias LocationSimulator.{Dsl.Source, DynamicSupervisor, Gpx, Pipeline}

  @type start_result :: :ok | {:error, term()}

  @doc """
  Starts workers with a pipeline module and runtime config.

  The pipeline module defines the GPS source and the plug chain.
  The config map supplies runtime parameters (worker count, event count, etc.).

  Returns `:ok`, or `{:error, reason}` when a worker fails to start or the
  configured GPX glob matches no files.
  """
  @spec start(module(), map()) :: start_result()
  def start(pipeline_mod, runtime_config) when is_atom(pipeline_mod) and is_map(runtime_config) do
    runtime_config
    |> Map.put(:pipeline, pipeline_mod)
    |> validate_gpx!(gpx_glob(pipeline_mod, runtime_config))
    |> build_worker_specs()
    |> DynamicSupervisor.start_simulator()
  end

  @doc """
  Starts workers using a plain config map (legacy API).

  See the module doc for supported config keys.
  """
  @spec start(map()) :: start_result()
  def start(config) when is_map(config) do
    config
    |> validate_gpx!(Map.get(config, :gpx_file))
    |> build_worker_specs()
    |> DynamicSupervisor.start_simulator()
  end

  @doc "Starts one worker with the default / application config."
  @spec start() :: start_result()
  def start do
    default_config() |> build_worker_specs() |> DynamicSupervisor.start_simulator()
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
    # Read at runtime so consumers can configure after this library is compiled.
    app_config = Application.get_env(:location_simulator, :default_config, [])

    %{
      worker: fetch(app_config, :worker, 1),
      event: fetch(app_config, :event, 1),
      interval: fetch(app_config, :interval, 100),
      random_range: fetch(app_config, :random_range, 10),
      direction: fetch(app_config, :direction, :random),
      elevation: fetch(app_config, :elevation, 0),
      elevation_way: fetch(app_config, :elevation_way, :no_up_down),
      callback: fetch(app_config, :callback, LocationSimulator.LoggerEvent)
    }
  end

  defp fetch(app_config, key, default) do
    Keyword.get(app_config, key, default)
  end

  defp gpx_glob(pipeline_mod, runtime_config) do
    case Pipeline.__pipeline__(pipeline_mod) do
      {%Source{type: :gpx, gpx_file: glob}, _plugs} when is_binary(glob) -> glob
      _ -> Map.get(runtime_config, :gpx_file)
    end
  end

  defp validate_gpx!(config, nil), do: config

  defp validate_gpx!(config, glob) do
    Gpx.resolve_files!(glob)
    config
  end

  defp build_worker_specs(config), do: build_specs(config.worker, config, [])

  defp build_specs(0, _config, acc), do: acc

  defp build_specs(n, config, acc) do
    build_specs(n - 1, config, [{LocationSimulator.Worker, Map.put(config, :id, n)} | acc])
  end
end
