defmodule LocationSimulator.WorkerGpx do
  @moduledoc """
  Simulates GPS movement by replaying tracks from GPX files.

  Each worker loads a single GPX file and emits one GPS event per
  track-point.  The sleep interval between events is either:

  * A fixed integer (milliseconds)
  * `:gpx_time` – the actual delta between successive track-point timestamps

  See `LocationSimulator.Event` for the callback contract.
  """

  require Logger

  alias LocationSimulator.{Gpx, WorkerBase}

  # ── OTP ────────────────────────────────────────────────────────────────────

  @spec start_link(map()) :: {:ok, pid()}
  def start_link(arg), do: WorkerBase.start_link(__MODULE__, arg)

  @spec child_spec(map()) :: map()
  def child_spec(opts), do: WorkerBase.child_spec(__MODULE__, opts)

  # ── Entry point ────────────────────────────────────────────────────────────

  @doc "Entry point called by `start_link/1`."
  @spec init(map()) :: :ok
  def init(config) do
    id = Map.get(config, :id, self())
    state = WorkerBase.init_state()
    config = WorkerBase.fire_start!(config, state)

    gps_points = Gpx.read_gpx(config.gpx_file)

    Logger.info(
      "Worker #{inspect(id)}: loaded #{length(gps_points)} points from #{config.gpx_file}"
    )

    [first | rest] = gps_points

    gps = %{timestamp: 0, time: first.time, lat: first.lat, lon: first.lon, ele: first.ele}

    config = Map.put(config, :gps_data, rest)
    state = Map.put(state, :gps, gps)

    WorkerBase.maybe_register(config)

    loop(config, state)
  end

  # ── Private: loop (terminal) ───────────────────────────────────────────────

  defp loop(%{gps_data: []} = config, state) do
    WorkerBase.fire_stop!(config, state)
    :ok
  end

  # ── Private: loop (active) ─────────────────────────────────────────────────

  defp loop(%{id: id} = config, %{gps: last_gps} = state) do
    [point | rest] = config.gps_data
    config = Map.put(config, :gps_data, rest)

    sleep_ms = interval_ms(config.interval, last_gps, point)
    Process.sleep(sleep_ms)

    new_gps = %{
      timestamp: last_gps.timestamp + sleep_ms,
      time: point.time,
      lat: point.lat,
      lon: point.lon,
      ele: point.ele
    }

    state = Map.put(state, :gps, new_gps)

    {config, state, stop?} = dispatch_event(config, state)

    cond do
      stop? ->
        loop(Map.put(config, :gps_data, []), state)

      true ->
        receive do
          {:stop_worker, ^id} ->
            Logger.debug("Worker #{inspect(id)}: stop received from group manager")
            loop(Map.put(config, :gps_data, []), state)
        after
          0 ->
            loop(config, state)
        end
    end
  end

  # ── Private: helpers ───────────────────────────────────────────────────────

  defp interval_ms(:gpx_time, last_gps, point),
    do: NaiveDateTime.diff(point.time, last_gps.time, :millisecond)

  defp interval_ms(ms, _last, _point) when is_integer(ms), do: ms

  defp dispatch_event(%{callback: mod} = config, state) do
    case mod.event(config, state) do
      {:ok, new_config} -> {new_config, Map.update!(state, :success, &(&1 + 1)), false}
      {:error, _reason} -> {config, Map.update!(state, :failed, &(&1 + 1)), false}
      {:stop, _reason} -> {config, state, true}
    end
  end
end
