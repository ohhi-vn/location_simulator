defmodule LocationSimulator.GpxTest do
  use ExUnit.Case, async: true

  alias LocationSimulator.Gpx

  describe "read_gpx/1" do
    test "parses a valid GPX file" do
      points = Gpx.read_gpx("test/fixtures/test_track.gpx")
      assert length(points) == 3

      first = hd(points)
      assert first.lat == 10.0
      assert first.lon == 20.0
      assert first.ele == 100.0
      assert first.time == ~N[2024-01-01 00:00:00]
    end

    test "raises on nonexistent file" do
      assert_raise RuntimeError, ~r/cannot read file/, fn ->
        Gpx.read_gpx("test/fixtures/nonexistent.gpx")
      end
    end
  end

  describe "read_string_gpx/1" do
    test "parses GPX content with all fields" do
      content = """
      <?xml version="1.0" encoding="utf-8"?>
      <gpx version="1.1">
        <trk>
          <trkseg>
            <trkpt lat="15.5" lon="25.3">
              <ele>50.0</ele>
              <time>2024-06-15T12:30:00Z</time>
            </trkpt>
          </trkseg>
        </trk>
      </gpx>
      """

      [point] = Gpx.read_string_gpx(content)
      assert point.lat == 15.5
      assert point.lon == 25.3
      assert point.ele == 50.0
      assert point.time == ~N[2024-06-15 12:30:00]
    end

    test "defaults ele to 0 when missing" do
      content = """
      <?xml version="1.0" encoding="utf-8"?>
      <gpx version="1.1">
        <trk>
          <trkseg>
            <trkpt lat="1.0" lon="2.0">
              <time>2024-01-01T00:00:00Z</time>
            </trkpt>
          </trkseg>
        </trk>
      </gpx>
      """

      [point] = Gpx.read_string_gpx(content)
      assert point.ele == 0
    end

    test "sets time to nil when time tag is missing" do
      content = """
      <?xml version="1.0" encoding="utf-8"?>
      <gpx version="1.1">
        <trk>
          <trkseg>
            <trkpt lat="1.0" lon="2.0">
              <ele>10.0</ele>
            </trkpt>
          </trkseg>
        </trk>
      </gpx>
      """

      [point] = Gpx.read_string_gpx(content)
      assert point.time == nil
    end

    test "sets time to nil on invalid datetime" do
      content = """
      <?xml version="1.0" encoding="utf-8"?>
      <gpx version="1.1">
        <trk>
          <trkseg>
            <trkpt lat="1.0" lon="2.0">
              <ele>10.0</ele>
              <time>not-a-datetime</time>
            </trkpt>
          </trkseg>
        </trk>
      </gpx>
      """

      [point] = Gpx.read_string_gpx(content)
      assert point.time == nil
    end

    test "parses multiple track points" do
      content = """
      <?xml version="1.0" encoding="utf-8"?>
      <gpx version="1.1">
        <trk>
          <trkseg>
            <trkpt lat="1.0" lon="2.0"><time>2024-01-01T00:00:00Z</time></trkpt>
            <trkpt lat="3.0" lon="4.0"><time>2024-01-01T00:00:01Z</time></trkpt>
          </trkseg>
        </trk>
      </gpx>
      """

      points = Gpx.read_string_gpx(content)
      assert length(points) == 2
      assert Enum.map(points, & &1.lat) == [1.0, 3.0]
    end
  end
end
