defmodule LocationSimulator do
  @moduledoc """
  """
  require Logger

  alias LocationSimulator.DynamicSupervisor, as: Sup

  @doc """
  Start with config
  """
  def start(config) when is_map(config) do
    config
    |> generate_worker()
    |> Sup.start_childrens()
  end

  @doc """
  Start with default config
  """
  def start() do
    default_config()
    |> generate_worker()
    |> Sup.start_childrens()
  end

  def default_config() do
    Logger.debug("generating worker from config")
    config = Application.get_env(:location_simulator, :default_config)
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
          raise "missed counter for simu traffic"
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

    mod =
      case config[:callback] do
        nil ->
          raise "missed callback module"
        m ->
            m
      end

    %{
      worker: worker,
      event: event,
      interval: interval,
      random_range: random_range,
      callback: mod
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
    generate_worker(counter-1, config, [{LocationSimulator.Worker, config} | workers])
  end
end
