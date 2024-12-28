defmodule LocationSimulator do
  @moduledoc """
  This is main api of library.

  To start simple call
    iex> LocationSimulator.start()

  Or start with your config
    iex> config = LocationSimulator.default_config()
    iex> config = Map.put(config, :worker, 1)
    iex> LocationSimulator.start(config)

  """

  require Logger

  alias LocationSimulator.DynamicSupervisor, as: Sup

  @app_default_config Application.compile_env(:location_simulator, :default_config)


  @doc """
  Start with config.

  The config is a map type.

  Config has info like:

    ```
    %{
      group_id: "group_id", # group id for workers, default is nil, using for stop all workers in a group.
      worker: 3,  # number of worker will run
      event: 100, # number of GPS events will be trigger for a worker
      interval: 1000, # this & random_range used for sleep between GPS events, if value is :infinity worker will run forever (you still stop by return {:stop, reason})
      random_range: 0, # 0 mean no random, other positive will be used for generate extra random sleep time
      callback: MyCallbackModule # your module will handle data
    }
    ```

  :id is reserved for worker's id.
  :group_id if added will be used for stop all workers in a group.

  If you need pass your data to callback module you can add that in the config.

  The config can be change after every event.
  """
  @spec start(%{:worker => non_neg_integer, optional(any) => any}) :: :ok
  def start(config) when is_map(config) do
    config
    |> generate_worker()
    |> Sup.start_simulator()
  end

  @doc """
  Start with default config.

  In this case, library just uses Logger to log data in every event.
  Remember start with default has no id then we can't stop worker by id.
  """
  @spec start() :: :ok
  def start() do
    default_config()
    |> generate_worker()
    |> Sup.start_simulator()
  end

  @doc """
  Stop all workers.

  For using this function, you need to start with group_id options in config.
  """
  @spec stop(group_id :: any()) :: :ok
  def stop(group_id) do
    Registry.dispatch(LocationSimulator.Registry, group_id, fn entries ->
      Logger.debug("stop all workers in group: #{inspect group_id}, number of workers: #{length(entries)}")
      for {pid, id} <- entries do
        send(pid, {:stop_worker, id})
        Logger.debug("sent stop to worker: #{inspect id} of groupd #{inspect group_id}")
      end
    end)
  end

  @doc """
  Get default config of library.
  """
  @spec default_config() :: map
  def default_config() do
    Logger.debug("generating worker from config")
    config = @app_default_config

    worker =
      case config[:worker] do
        # default is one worker.
        nil ->
          1
        n when is_integer(n) and n > 0 ->
          n
      end

    event =
      case config[:event] do
        nil ->
          1
        n when is_integer(n)->
          n
      end

    interval =
      case config[:interval] do
        nil ->
          100
        n when is_integer(n)->
            n
        :gpx_time ->
          :gpx_time
      end

    random_range =
      case config[:random_range] do
        nil ->
          10
        n when is_integer(n)->
            n
      end

    elevation =
      case config[:elevation] do
        nil ->
          0
        n when is_integer(n)->
            n
      end

    elevation_way =
      case config[:elevation_way] do
        nil ->
          :no_up_down
        direction ->
            direction
      end

    mod =
      case config[:callback] do
        nil ->
          LocationSimulator.LoggerEvent
        m ->
            m
      end

    %{
      worker: worker,
      event: event,
      interval: interval,
      random_range: random_range,
      direction: :random,
      callback: mod,
      elevation: elevation,
      elevation_way: elevation_way
    }
  end

  ## private functions ##

  @spec generate_worker(map) :: list
  # generate worker from config with gpx file.
  defp generate_worker(%{gpx_file: wildcard_path} = config) do
    list_files = wildcard_path |> Path.wildcard()

    if length(list_files) == 0 do
      raise "No GPX file found from path: #{wildcard_path}"
    end

    %{worker: worker} = config
    generate_worker_gpx(worker, config, list_files, list_files, [])
  end
  # generate worker from config with fake data.
  defp generate_worker(config) do
    %{worker: worker} = config
    generate_worker(worker, config, [])
  end

  @spec generate_worker(non_neg_integer(), map, list) :: list
  defp generate_worker(0, _config, workers) do
    workers
  end

  defp generate_worker(counter, config, workers) do
    generate_worker(counter-1, config, [{LocationSimulator.Worker, Map.put(config, :id, counter)} | workers])
  end

  @spec generate_worker_gpx(non_neg_integer(), map, list, list, list) :: list
  defp generate_worker_gpx(0, _config, _current_files, _files, workers) do
    workers
  end

  defp generate_worker_gpx(counter, config, [], files, workers) do
    generate_worker_gpx(counter, config, files, files, workers)
  end
  defp generate_worker_gpx(counter, config, [file|rest_files], files, workers) do
    config =
      config
      |> Map.put(:id, counter)
      |> Map.put(:gpx_file, file)

    generate_worker_gpx(counter-1, config, rest_files, files, [{LocationSimulator.WorkerGpx, config} | workers])
  end
end
