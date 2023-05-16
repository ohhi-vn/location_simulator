defmodule LocationSimulator.LoggerEvent do
  @behaviour LocationSimulator.Event

  require Logger

  @impl true
  def start(config, state) do
    id = Map.get(config, :id, self())
    %{start_time: start_time} = state
    Logger.info("Start location worker: #{inspect id}")

    {:ok, config}
  end

  @impl true
  def event(config, %{gps: gps} = state) do
    id = Map.get(config, :id, self())
    Logger.info("#{inspect id}, new GPS: #{inspect gps}")

    {:ok, config}
  end

  @impl true
  def stop(config, state) do
    id = Map.get(config, :id, self())
    %{start_time: start_time} = state
    %{stop_time: stop_time} = state
    %{success: s} = state
    %{failed: f} = state
    %{error: e} = state

    Logger.info("#{id} is stopped, time: #{stop_time - start_time}s, success: #{s}, failed: #{f}, error: #{e}")

    {:ok, config}
  end
end
