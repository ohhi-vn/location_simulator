defmodule LocationSimulator.Worker do
  @moduledoc """
  Worker is a simulator that use for generating GPS data.

  Worker will call client follow :callback setting in config.

  Two start/stop event is used for start or init data and clean if need.

  `event` api is used for put GPS data to client.

  Callbacks are declared in `LocationSimulator.Event` module.
  """

  require Logger

  import LocationSimulator.Gps


  @doc """
  Support for starting from supervisor.
  """
  @spec start_link(any) :: {:ok, pid}
  def start_link(arg) do
    pid = spawn_link(__MODULE__, :init, [arg])
    {:ok, pid}
  end


  @doc """
  Generate child spec for supervisor.
  """
  @spec child_spec(map) :: %{
    id: any,
    restart: any,
    shutdown: any,
    start: {LocationSimulator.Worker, :start_link, [map, ...]},
    type: :worker
  }
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

    config =
      case Map.get(config, :direction, :random) do
        :random ->
          direction = Enum.random([:north, :south, :east, :west, :north_east, :north_west, :south_east, :south_west])
          Map.put(config, :direction, direction)
        _ ->
          config
      end

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

    gps =
      if Map.has_key?(config, :started_gps) do
        {lat, lon, ele} = Map.get(config, :started_gps)
        %{
          timestamp: 0,
          lon: lon,
          lat: lat,
          ele: ele
        }
      else
        # random start point.
        {lat, lon} = generate_pos()

        # get started elevation, default is 0
        ele =
          case Map.get(config, :elevation) do
            n when is_integer(n) ->
              n
            _ ->
              0
          end

        %{
          timestamp: 0,
          lon: lon,
          lat: lat,
          ele: ele
        }
      end

    if Map.has_key?(config, :group_id) do
      Registry.register(LocationSimulator.Registry, config.group_id, config.id)
    end

    state = Map.put(state, :gps, gps)

    counter = Map.get(config, :event, :infinity)

    Logger.debug("start loop with counter: #{inspect counter}")
    loop_event(config, state, counter)
  end


  # Main function of worker, GPS data will be generated in here then trigger client's api.
  # After fired all GPS data/ client send signal to stop, the function will fire stop event.
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

  defp loop_event(%{id: id} = config, %{gps: last_gps} = state, counter) do

    direction = Map.get(config, :direction, :up_right)

    # generate next gps based on last gps.
    {lat, lon} = generate_next_pos(last_gps.lat, last_gps.lon, random_lati_step(direction), random_long_step(direction))
    # get next elevation
    ele =
      case Map.get(config, :elevation_way) do
        :up ->
          last_gps.ele + Enum.random(0..2)
        :down ->
          last_gps.ele - Enum.random(0..2)
        _ ->
          last_gps.ele
      end

    %{interval: interval} = config
    %{random_range: random_range} = config
    sleep_time = interval + Enum.random(0..random_range)
    Process.sleep(sleep_time)

    new_gps = %{
      timestamp: sleep_time + last_gps.timestamp,
      lon: lon,
      lat: lat,
      ele: ele
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
          Logger.debug " by client, reason: #{inspect reason}"
          {config, state, :stop}
      end

    case counter do
        :infinity ->
          loop_event(config, state, counter)
        :stop ->
          Logger.debug("#{inspect id}, stop by callback.")
          loop_event(config, state, 0)
        _ ->
          receive do
            {:stop_worker, ^id} ->
              Logger.debug("#{inspect id}, stop by client.")
              loop_event(config, state, 0)
            after 0 ->
              loop_event(config, state, counter-1)
          end
      end
  end

  defp get_timestamp do
    :os.system_time(:seconds)
  end

  # direction: :north, :south, :east, :west, :north_east, :north_west, :south_east, :south_west
  defp random_long_step(direction) when is_atom(direction) do
    # TO-DO: move random step distance to config
    case direction do
      n when n in [:north_east, :south_east] ->
        Enum.random(1..5)
      l when l in [:north_west, :south_west] ->
        Enum.random(-5..-1)
      k when k in [:north, :south] ->
        0
      :east ->
        Enum.random(1..5)
      :west ->
        Enum.random(-5..-1)
    end
  end

  defp random_lati_step(direction) when is_atom(direction) do
    case direction do
      n when n in [:north_east, :north_west] ->
        Enum.random(1..5)
      l when l in [:south_east, :south_west] ->
        Enum.random(-5..-1)
      k when k in [:east, :west] ->
        0
      :north ->
        Enum.random(1..5)
      :south ->
        Enum.random(-5..-1)
    end
  end
end
