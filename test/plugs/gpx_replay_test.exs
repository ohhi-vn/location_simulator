defmodule LocationSimulator.Plug.GpxReplayTest do
  use ExUnit.Case, async: true

  alias LocationSimulator.Plug.GpxReplay
  alias LocationSimulator.Gpx.GpsPoint

  defp make_point(opts \\ []) do
    %GpsPoint{
      lat: opts[:lat] || 10.0,
      lon: opts[:lon] || 20.0,
      ele: opts[:ele] || 100.0,
      time: opts[:time] || ~N[2024-01-01 00:00:00]
    }
  end

  defp make_pipeline(overrides \\ []) do
    %{
      config: Map.merge(%{interval: 100, gpx_data: overrides[:gps_data] || []}, overrides[:config] || %{}),
      state: overrides[:state] || %{},
      gps: nil,
      halted: false,
      assigns: %{}
    }
  end

  describe "init/1" do
    test "returns opts as-is" do
      assert GpxReplay.init([foo: :bar]) == [foo: :bar]
      assert GpxReplay.init(%{}) == %{}
    end
  end

  describe "call/2 with empty gps_data" do
    test "sets halted to true" do
      pipeline = make_pipeline(gps_data: [])
      result = GpxReplay.call(pipeline, [])
      assert result.halted == true
    end
  end

  describe "call/2 with gps_data" do
    test "pops the first point and updates pipeline" do
      point = make_point()
      pipeline = make_pipeline(gps_data: [point], config: %{interval: 50})

      result = GpxReplay.call(pipeline, [])

      assert result.halted == false
      assert result.gps.lat == 10.0
      assert result.gps.lon == 20.0
      assert result.gps.ele == 100.0
      assert result.gps.time == ~N[2024-01-01 00:00:00]
      assert is_integer(result.gps.timestamp)
      assert result.config.gps_data == []
      assert is_map_key(result.state, :gps)
    end

    test "sets sleep_ms in assigns for integer interval" do
      point = make_point()
      pipeline = make_pipeline(gps_data: [point], config: %{interval: 200})

      result = GpxReplay.call(pipeline, [])
      assert result.assigns.sleep_ms == 200
    end

    test "sleep_ms is 0 for :gpx_time on first point" do
      point = make_point()
      pipeline = make_pipeline(gps_data: [point], config: %{interval: :gpx_time})

      result = GpxReplay.call(pipeline, [])
      assert result.assigns.sleep_ms == 0
    end

    test "sleep_ms uses NaiveDateTime.diff for :gpx_time on subsequent points" do
      point1 = make_point(time: ~N[2024-01-01 00:00:01])
      point2 = make_point(time: ~N[2024-01-01 00:00:03])

      pipeline = make_pipeline(
        gps_data: [point2],
        config: %{interval: :gpx_time},
        state: %{last_point_time: point1.time}
      )

      result = GpxReplay.call(pipeline, [])
      assert result.assigns.sleep_ms == 2000
    end

    test "sleep_ms clamps to 0 when point_time is before last time" do
      point1 = make_point(time: ~N[2024-01-01 00:00:10])
      point2 = make_point(time: ~N[2024-01-01 00:00:05])

      pipeline = make_pipeline(
        gps_data: [point2],
        config: %{interval: :gpx_time},
        state: %{last_point_time: point1.time}
      )

      result = GpxReplay.call(pipeline, [])
      assert result.assigns.sleep_ms == 0
    end
  end
end
