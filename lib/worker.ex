defmodule LocationSimulator.Worker do
  @moduledoc """

  """

  require Logger

  import LocationSimulator.Gps

  def start_link(arg) do
    pid = spawn_link(__MODULE__, :init, [arg])
    {:ok, pid}
  end

  def init(config) when is_map(config) do
    state = %{
      start_time: get_timestamp(),
      success: 0,
      failed: 0,
      error: 0
    }

    id = Map.get(config, :id, self())
    %{callback: mod} = config

    Logger.debug("#{inspect id}, call start event")

    # send start event
    config = case mod.start(config, state) do
      {:ok, new_config} ->
        new_config
      {:error, reason} ->
        err = "call start event failed: #{inspect reason}"
        Logger.error(err)
        raise err
    end

    :rand.seed(:exsss)

    # random start point.
    {lati, long} = generate_pos()

    gps = %{
        timestamp: 0,
        long: long,
        lati: lati
      }

    state = Map.put(state, :gps, gps)

    counter = Map.get(config, :event, :infinity)

    Logger.debug("start loop with counter: #{inspect counter}")
    loop_event(config, state, counter)
  end

  def child_spec(opts) when is_map(opts) do
    %{
      id: Map.get(opts, :id, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart:  Map.get(opts, :restart, :temporary),
      shutdown: Map.get(opts, :shutdown, :brutal_kill)
    }
  end

  defp loop_event(config, state, 0) do
    stop_time = get_timestamp()
    state = Map.put(state, :stop_time, stop_time)
    %{callback: mod} = config
    # send stop event
    config = case mod.stop(config, state) do
      {:ok, new_config} ->
        new_config
      {:error, reason} ->
        err = "call start event failed: #{inspect reason}"
        Logger.error(err)
        raise err
    end

    %{start_time: start_time} = state
    %{success: s} = state
    %{failed: f} = state
    %{error: e} = state

    id = Map.get(config, :id, self())
    Logger.debug "Worker(#{inspect id}) DONE!, time: #{stop_time - start_time}s, success: #{s}, failed: #{f}, error: #{e}"
  end
  defp loop_event(config, %{gps: last_gps} = state, counter) do

    {lati, long} = generate_next_pos(last_gps.lati, last_gps.long, Enum.random(1..5), Enum.random(1..5))

    %{interval: interval} = config
    %{random_range: random_range} = config
    sleep_time = interval + Enum.random(0..random_range)
    Process.sleep(sleep_time)

    new_gps = %{
      timestamp: sleep_time + last_gps.timestamp,
      long: long,
      lati: lati,
      alti: 0
    }

    state = Map.put(state, :gps, new_gps)
    %{callback: mod} = config

    {config, state, counter} =
      case mod.event(config, state) do
        {:ok, config} ->
          {config, Map.update!(state, :success, &(&1 + 1)), counter}
        {:error, reason} ->
          Logger.debug "failed to post data return code: #{inspect reason}"
          {config, Map.update!(state, :failed, &(&1 + 1)), counter}
        {:stop, reason} ->
          Logger.debug "stop worker, reason: #{inspect reason}"
          {config, state, :stop}
      end

    case counter do
        :infinity ->
          loop_event(config, state, counter)
        :stop ->
          id = Map.get(config, :id, self())
          Logger.debug("#{inspect id} stop by callback, reason: #{inspect id}")
        _ ->
          loop_event(config, state, counter-1)
      end
  end

  defp get_timestamp do
    :os.system_time(:seconds)
  end
end
