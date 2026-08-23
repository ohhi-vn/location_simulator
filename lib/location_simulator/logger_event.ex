defmodule LocationSimulator.LoggerEvent do
  @moduledoc """
  Default callback for demo & develop.

  Just get data from `LocationSimulator.Worker` and print to console (by Logger).
  """

  @behaviour LocationSimulator.Event

  require Logger

  @impl true
  @spec start(map, map()) :: {:ok, map}
  def start(config, state) do
    id = Map.get(config, :id, self())
    %{start_time: start_time} = state
    Logger.info("Start location worker: #{inspect(id)}, timestamp: #{inspect(start_time)}")

    {:ok, config}
  end

  @impl true
  @spec event(map, map) :: {:ok, map}
  def event(config, %{gps: gps} = _state) do
    id = Map.get(config, :id, self())
    Logger.info("#{inspect(id)}, new GPS: #{inspect(gps)}")

    {:ok, config}
  end

  @impl true
  @spec stop(map, map) :: {:ok, map}
  def stop(
        config,
        %{start_time: start_time, stop_time: stop_time, success: s, failed: f} = _state
      ) do
    id = Map.get(config, :id, self())

    Logger.info(
      "#{inspect(id)} is stopped, time: #{stop_time - start_time}s, success: #{s}, failed: #{f}"
    )

    {:ok, config}
  end
end
