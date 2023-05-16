defmodule LocationSimulator do
  @moduledoc """
  """
  require Logger

  alias LocationSimulator.DynamicSupervisor, as: Sup

  @doc """
  Start with config
  """
  def start(config) when is_map(config) do
    Sup.start_childrens(config)
  end

  @doc """
  Start with default config
  """
  def start() do
    Sup.start_childrens(default_config())
  end


  ## private functions ##

  defp default_config() do
    Logger.info("generating worker from config")
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
          1000
        n when is_integer(n)->
            n
      end

    random_range =
      case config[:random_range] do
        nil ->
          100
        n when is_integer(n)->
            n
      end

    %{
      worker: worker,
      event: event,
      interval: interval,
      random_range: random_range
    }
  end
end
