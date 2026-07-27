defmodule LocationSimulator.Plug.GpxReplay do
  @moduledoc """
  Replays GPS points from a GPX track file.

  Expects `config.gpx_data` to be a list of remaining `%Gpx.GpsPoint{}`
  structs. Each call pops the next point and updates `state.gps`.

  When the track is exhausted, sets `halted: true` on the pipeline.
  """

  @behaviour LocationSimulator.Plug

  require Logger

  @impl true
  def init(opts), do: opts

  @impl true
  def call(pipeline, _opts) do
    %{config: config, state: state} = pipeline

    case config.gpx_data do
      [] ->
        Logger.debug("GPX track exhausted, halting worker")
        %{pipeline | halted: true}

      [%{time: time, lat: lat, lon: lon, ele: ele} | rest] ->
        sleep_ms = interval_ms(config.interval, state, time)
        now = :os.system_time(:millisecond)

        new_gps = %{
          lat: lat,
          lon: lon,
          ele: ele,
          timestamp: now,
          time: time
        }

        config = Map.put(config, :gps_data, rest)
        state = Map.put(state, :gps, new_gps)

        %{
          pipeline
          | config: config,
            state: state,
            gps: new_gps,
            assigns: Map.put(pipeline.assigns || %{}, :sleep_ms, sleep_ms)
        }
    end
  end

  defp interval_ms(:gpx_time, state, point_time) do
    case Map.get(state, :last_point_time) do
      nil -> 0
      last -> NaiveDateTime.diff(point_time, last, :millisecond) |> max(0)
    end
  end

  defp interval_ms(ms, _state, _point_time) when is_integer(ms), do: ms
end
