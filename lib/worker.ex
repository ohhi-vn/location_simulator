defmodule LocationSimulator.Worker do
  @moduledoc """
  Worker simulator that generates synthetic GPS data.

  Each worker picks a travel direction (or randomises one if not supplied),
  then emits GPS events at the configured interval until the event count is
  exhausted, the callback requests a stop, or a group-stop message arrives.

  See `LocationSimulator.Event` for the callback contract.
  """

  require Logger

  import LocationSimulator.Gps
  alias LocationSimulator.WorkerBase

  # ── OTP ────────────────────────────────────────────────────────────────────

  @spec start_link(map()) :: {:ok, pid()}
  def start_link(arg), do: WorkerBase.start_link(__MODULE__, arg)

  @spec child_spec(map()) :: map()
  def child_spec(opts), do: WorkerBase.child_spec(__MODULE__, opts)

  # ── Entry point ────────────────────────────────────────────────────────────

  @doc "Entry point called by `start_link/1`."
  @spec init(map()) :: :ok
  def init(config) do
    state = WorkerBase.init_state()
    config = resolve_direction(config)
    config = WorkerBase.fire_start!(config, state)

    :rand.seed(:exsss)

    gps = initial_gps(config)
    state = Map.put(state, :gps, gps)
    counter = Map.get(config, :event, :infinity)

    WorkerBase.maybe_register(config)

    Logger.debug(
      "Worker #{inspect(Map.get(config, :id))}: starting loop, events=#{inspect(counter)}"
    )

    loop(config, state, counter)
  end

  # ── Private: direction ─────────────────────────────────────────────────────

  @directions [:north, :south, :east, :west, :north_east, :north_west, :south_east, :south_west]

  # Explicit :random → pick one
  defp resolve_direction(%{direction: :random} = config) do
    Map.put(config, :direction, Enum.random(@directions))
  end

  # Already a specific direction → keep it
  defp resolve_direction(%{direction: _} = config), do: config
  # Key missing entirely → same as :random
  defp resolve_direction(config) do
    Map.put(config, :direction, Enum.random(@directions))
  end

  # ── Private: initial GPS ───────────────────────────────────────────────────

  defp initial_gps(%{started_gps: {lat, lon, ele}}) do
    %{timestamp: 0, lat: lat, lon: lon, ele: ele}
  end

  defp initial_gps(config) do
    {lat, lon} = generate_pos()
    ele = Map.get(config, :elevation, 0)
    %{timestamp: 0, lat: lat, lon: lon, ele: ele}
  end

  # ── Private: loop (terminal) ───────────────────────────────────────────────

  defp loop(config, state, 0) do
    WorkerBase.fire_stop!(config, state)
    :ok
  end

  # ── Private: loop (active) ─────────────────────────────────────────────────

  defp loop(%{id: id} = config, %{gps: last_gps} = state, counter) do
    sleep_ms = sleep_duration(config)
    Process.sleep(sleep_ms)

    new_gps = next_gps(config, last_gps, sleep_ms)
    state = Map.put(state, :gps, new_gps)

    {config, state, next_counter} = dispatch_event(config, state, counter)

    case next_counter do
      :stop ->
        loop(config, state, 0)

      :infinity ->
        receive do
          {:stop_worker, ^id} ->
            Logger.debug("Worker #{inspect(id)}: stop received from group manager")
            loop(config, state, 0)
        after
          0 ->
            loop(config, state, :infinity)
        end

      n ->
        receive do
          {:stop_worker, ^id} ->
            Logger.debug("Worker #{inspect(id)}: stop received from group manager")
            loop(config, state, 0)
        after
          0 ->
            loop(config, state, n - 1)
        end
    end
  end

  # ── Private: GPS generation ────────────────────────────────────────────────

  defp next_gps(config, last, sleep_ms) do
    # direction is guaranteed present after resolve_direction/1
    direction = Map.get(config, :direction, :north)

    {lat, lon} =
      generate_next_pos(
        last.lat,
        last.lon,
        lat_step(direction),
        lon_step(direction)
      )

    ele = next_elevation(Map.get(config, :elevation_way, :no_up_down), last.ele)

    %{timestamp: last.timestamp + sleep_ms, lat: lat, lon: lon, ele: ele}
  end

  defp next_elevation(:up, ele), do: ele + Enum.random(0..2)
  defp next_elevation(:down, ele), do: ele - Enum.random(0..2)
  defp next_elevation(_, ele), do: ele

  # ── Private: step helpers ──────────────────────────────────────────────────

  # Longitude step (east/west component)
  defp lon_step(dir) do
    case dir do
      d when d in [:north_east, :south_east, :east] -> Enum.random(1..5)
      d when d in [:north_west, :south_west, :west] -> Enum.random(-5..-1//1)
      _ -> 0
    end
  end

  # Latitude step (north/south component)
  defp lat_step(dir) do
    case dir do
      d when d in [:north_east, :north_west, :north] -> Enum.random(1..5)
      d when d in [:south_east, :south_west, :south] -> Enum.random(-5..-1//1)
      _ -> 0
    end
  end

  # ── Private: event dispatch ────────────────────────────────────────────────

  defp dispatch_event(%{callback: mod} = config, state, counter) do
    case mod.event(config, state) do
      {:ok, new_config} -> {new_config, Map.update!(state, :success, &(&1 + 1)), counter}
      {:error, _reason} -> {config, Map.update!(state, :failed, &(&1 + 1)), counter}
      {:stop, _reason} -> {config, state, :stop}
    end
  end

  defp sleep_duration(%{interval: interval, random_range: range}) do
    interval + Enum.random(0..range)
  end

  defp sleep_duration(%{interval: interval}), do: interval
end
