defmodule LocationSimulator.Plug.GpxReplayTest do
  use ExUnit.Case, async: true

  alias LocationSimulator.Gpx.GpsPoint
  alias LocationSimulator.Plug.GpxReplay

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
      config: Map.merge(%{interval: 100}, overrides[:config] || %{}),
      state: Map.merge(%{gpx_data: overrides[:gps_data] || []}, overrides[:state] || %{}),
      gps: nil,
      halted: false,
      assigns: %{}
    }
  end

  describe "init/1" do
    test "returns opts as-is" do
      assert GpxReplay.init(foo: :bar) == [foo: :bar]
      assert GpxReplay.init(%{}) == %{}
    end
  end

  describe "call/2 with empty gpx_data" do
    test "sets halted to true" do
      pipeline = make_pipeline(gps_data: [])
      result = GpxReplay.call(pipeline, [])
      assert result.halted == true
    end

    test "halts when state has no gpx_data key at all" do
      pipeline = %{config: %{}, state: %{}, gps: nil, halted: false, assigns: %{}}
      result = GpxReplay.call(pipeline, [])
      assert result.halted == true
    end
  end

  describe "call/2 with gpx_data" do
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
      assert result.state.gpx_data == []
      assert result.state.gps == result.gps
      refute Map.has_key?(result.assigns, :sleep_ms)
    end

    test "consumes points in order" do
      p1 = make_point(lat: 1.0)
      p2 = make_point(lat: 2.0)

      pipeline = make_pipeline(gps_data: [p1, p2])
      result = GpxReplay.call(pipeline, [])

      assert result.gps.lat == 1.0
      assert Enum.map(result.state.gpx_data, & &1.lat) == [2.0]

      result2 = GpxReplay.call(result, [])
      assert result2.gps.lat == 2.0
      assert result2.state.gpx_data == []
    end
  end
end
