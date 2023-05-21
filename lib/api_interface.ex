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
      worker: 3,  # number of worker will run
      event: 100, # number of GPS events will be trigger for a worker
      interval: 1000, # this & random_range used for sleep between GPS events, if value is :infinity worker will run forever (you still stop by return {:stop, reason})
      random_range: 0, # 0 mean no random, other positive will be used for generate extra random sleep time
      callback: MyCallbackModule # your module will handle data
    }
    ```

  :id is reserved for worker's id.

  If you need pass your data to callback module you can add that in the config.

  The config can be change after every event.
  """
  def start(config) when is_map(config) do
    config
    |> generate_worker()
    |> Sup.start_simulator()
  end

  @doc """
  Start with default config.

  In this case, library just uses Logger to log data in every event.
  """
  def start() do
    default_config()
    |> generate_worker()
    |> Sup.start_simulator()
  end

  @doc """
  Get default config of library.
  """
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
      end

    random_range =
      case config[:random_range] do
        nil ->
          10
        n when is_integer(n)->
            n
      end

    altitude =
      case config[:altitude] do
        nil ->
          0
        n when is_integer(n)->
            n
      end

    altitude_way =
      case config[:altitude_way] do
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
      altitude: altitude,
      altitude_way: altitude_way
    }
  end

  ## private functions ##

  defp generate_worker(config) do
    %{worker: worker} = config
    generate_worker(worker, config, [])
  end

  defp generate_worker(0, _config, workers) do
    workers
  end

  defp generate_worker(counter, config, workers) do
    generate_worker(counter-1, config, [{LocationSimulator.Worker, Map.put(config, :id, counter)} | workers])
  end
end
