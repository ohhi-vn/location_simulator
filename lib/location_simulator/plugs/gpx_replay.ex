defmodule LocationSimulator.Plug.GpxReplay do
  @moduledoc """
  Replays GPS points from a GPX track file.

  Expects `state.gpx_data` to be a list of remaining `%Gpx.GpsPoint{}`
  structs (loaded by the worker). Each call pops the next point and updates
  `state.gps`.

  When the track is exhausted, sets `halted: true` on the pipeline.

  Timing is owned by the worker loop (`interval: :gpx_time` or fixed ms).
  """

  @behaviour LocationSimulator.Plug

  require Logger

  @impl true
  def init(opts), do: opts

  @impl true
  def call(pipeline, _opts) do
    %{config: config, state: state} = pipeline

    case state do
      %{gpx_data: [%{time: time, lat: lat, lon: lon, ele: ele} | rest]} ->
        new_gps = %{
          lat: lat,
          lon: lon,
          ele: ele,
          timestamp: :os.system_time(:millisecond),
          time: time
        }

        # Keys may be absent on a freshly built pipeline, so use Map.put
        # instead of struct-update syntax.
        state =
          state
          |> Map.put(:gpx_data, rest)
          |> Map.put(:gps, new_gps)

        %{pipeline | config: config, state: state, gps: new_gps}

      _ ->
        Logger.debug("GPX track exhausted, halting worker")
        %{pipeline | halted: true}
    end
  end
end
