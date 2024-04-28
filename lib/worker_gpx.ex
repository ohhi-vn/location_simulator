defmodule LocationSimulator.WorkerGpx do
  @moduledoc """
  Worker is a simulator that use for generating GPS data.

  Worker will call client follow :callback setting in config.

  Two start/stop event is used for start or init data and clean if need.

  `event` api is used for put GPS data to client.

  Callbacks are declared in `LocationSimulator.Event` module.
  """

  require Logger

  alias LocationSimulator.Gpx

  @doc """
  Support for starting from supervisor.
  """
  @spec start_link(any) :: {:ok, pid}
  def start_link(arg) do
    pid = spawn_link(__MODULE__, :init, [arg])
    {:ok, pid}
  end


  @spec child_spec(map()) :: %{
          id: any(),
          restart: any(),
          shutdown: any(),
          start: {LocationSimulator.WorkerGpx, :start_link, [map(), ...]},
          type: :worker
        }
  @doc """
  Generate child spec for supervisor.
  """
  def child_spec(opts) when is_map(opts) do
    %{
      id: Map.get(opts, :id, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart:  Map.get(opts, :restart, :temporary),
      shutdown: Map.get(opts, :shutdown, :brutal_kill)
    }
  end

  @doc """
  Entry point of worker, start event will be fired from here.

  Init some data and go to loop function for generating GPS data.

  Root GPS data will be generated in this function.
  """
  @spec init(map) :: :ok
  def init(config) when is_map(config) do
    state = %{
      start_time: get_timestamp(),
      success: 0,
      failed: 0,
      error: 0
    }

    # load GPS data from GPX file
    gps_data = Gpx.read_gpx(config.gpx_file)

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

    # get first gps data
    [gps | gps_data] = gps_data
    config = Map.put(config, :gps_data, gps_data)

    new_gps = %{
      timestamp: 0,
      time: gps.time,
      lon: gps.lon,
      lat: gps.lat,
      ele: gps.ele
    }

    state = Map.put(state, :gps, new_gps)

    Logger.debug("start loop with gps data from file : #{inspect config.gpx_file}")
    loop_event(config, state)
  end

  # Main function of worker, GPS data will be generated in here then trigger client's api.
  # After fired all GPS data/ client send signal to stop, the function will fire stop event.
  defp loop_event(%{gps_data: []} = config, state) do
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

  # in case of gpx_time, we will use timestamp from gpx file.
  defp loop_event(%{interval: :gpx_time} = config, %{gps: last_gps} = state) do
    # get next gps data
    [gps | gps_data] = config.gps_data
    config = Map.put(config, :gps_data, gps_data)

    # sleep time between two gps data
    # TO-DO: Move sleep to send event for can cancel sleep.
    interval = NaiveDateTime.diff(gps.time, last_gps.time, :second) * 1_000
    Process.sleep(interval)

    new_gps = %{
      timestamp: interval + last_gps.timestamp,
      time: gps.time,
      lon: gps.lon,
      lat: gps.lat,
      ele: gps.ele
    }

    state = Map.put(state, :gps, new_gps)
    %{callback: mod} = config

    {config, state, is_stop} =
      case mod.event(config, state) do
        {:ok, config} ->
          {config, Map.update!(state, :success, &(&1 + 1)), :continue}
        {:error, reason} ->
          Logger.debug "failed to post data return code: #{inspect reason}"
          {config, Map.update!(state, :failed, &(&1 + 1)), :continue}
        {:stop, reason} ->
          Logger.debug "stop worker by client, reason: #{inspect reason}"
          {config, state, :stop}
      end

    case is_stop do
        :stop ->
          id = Map.get(config, :id, self())
          Logger.debug("#{inspect id} stop by callback, id: #{inspect id}")

          loop_event(Map.put(config, :gps_data, []), state)
        _ ->
          loop_event(config, state)
      end
  end

  defp loop_event(config, %{gps: last_gps} = state) do
    # get next gps data
    [gps | gps_data] = config.gps_data
    config = Map.put(config, :gps_data, gps_data)

    Process.sleep(config.interval)

    new_gps = %{
      timestamp: config.interval + last_gps.timestamp,
      lon: gps.lon,
      lat: gps.lat,
      ele: gps.ele
    }

    state = Map.put(state, :gps, new_gps)
    %{callback: mod} = config

    {config, state, is_stop} =
      case mod.event(config, state) do
        {:ok, config} ->
          {config, Map.update!(state, :success, &(&1 + 1)), :continue}
        {:error, reason} ->
          Logger.debug "failed to post data return code: #{inspect reason}"
          {config, Map.update!(state, :failed, &(&1 + 1)), :continue}
        {:stop, reason} ->
          Logger.debug "stop worker by client, reason: #{inspect reason}"
          {config, state, :stop}
      end

    case is_stop do
        :stop ->
          id = Map.get(config, :id, self())
          Logger.debug("#{inspect id} stop by callback, id: #{inspect id}")
          loop_event(Map.put(config, :gps_data, []), state)
        _ ->
          loop_event(config, state)
      end
  end

  defp get_timestamp do
    :os.system_time(:seconds)
  end
end
