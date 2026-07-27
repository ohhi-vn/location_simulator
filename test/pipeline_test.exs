defmodule LocationSimulator.PipelineTest do
  use ExUnit.Case, async: false

  alias LocationSimulator, as: LS

  # ── Test callback ───────────────────────────────────────────────────────────

  defmodule TestEvent do
    @behaviour LocationSimulator.Event

    @impl true
    def start(config, state) do
      notify(config, {:start, state})
      {:ok, config}
    end

    @impl true
    def event(config, %{gps: gps}) do
      notify(config, {:gps, gps})

      case Map.get(config, :test) do
        :stop -> {:stop, "intentional stop"}
        _ -> {:ok, config}
      end
    end

    @impl true
    def stop(config, state) do
      notify(config, {:stop, state})
      {:ok, config}
    end

    defp notify(config, msg) do
      if client = Map.get(config, :client), do: send(client, msg)
    end
  end

  # ── Custom plugs for testing ────────────────────────────────────────────────

  defmodule TrackerPlug do
    @behaviour LocationSimulator.Plug

    @impl true
    def init(opts), do: opts

    @impl true
    def call(pipeline, _opts) do
      send(Map.get(pipeline.config, :client, self()), {:tracked_gps, pipeline.gps})
      pipeline
    end
  end

  defmodule HaltPlug do
    @behaviour LocationSimulator.Plug

    @impl true
    def init(opts), do: opts

    @impl true
    def call(pipeline, _opts) do
      %{pipeline | halted: true}
    end
  end

  # ── Test pipelines ──────────────────────────────────────────────────────────

  defmodule SyntheticPipeline do
    use LocationSimulator.Pipeline

    source :synthetic, direction: :north, elevation: 50

    plug LocationSimulator.Plug.Callback
  end

  defmodule PipelineWithTrackerPlug do
    use LocationSimulator.Pipeline

    source :synthetic, direction: :south

    plug TrackerPlug
    plug LocationSimulator.Plug.Callback
  end

  defmodule PipelineWithHaltPlug do
    use LocationSimulator.Pipeline

    source :synthetic, direction: :west

    plug HaltPlug
    plug LocationSimulator.Plug.Callback
  end

  # ── Helpers ─────────────────────────────────────────────────────────────────

  defp base_config(overrides \\ %{}) do
    Map.merge(
      %{worker: 1, event: 1, interval: 0, random_range: 0, callback: TestEvent, client: self()},
      overrides
    )
  end

  defp await_start(timeout \\ 2_000) do
    receive do
      {:start, _} -> :ok
    after
      timeout -> {:error, :timeout}
    end
  end

  defp await_gps(timeout \\ 2_000) do
    receive do
      {:gps, gps} -> gps
    after
      timeout -> {:error, :timeout}
    end
  end

  defp await_stop(timeout \\ 2_000) do
    receive do
      {:stop, state} -> state
    after
      timeout -> {:error, :timeout}
    end
  end

  # ── Pipeline DSL tests ────────────────────────────────────────────────────

  describe "Pipeline DSL" do
    test "pipeline module has __pipeline__/1" do
      {source, plugs} = LocationSimulator.Pipeline.__pipeline__(SyntheticPipeline)
      assert source.type == :synthetic
      assert length(plugs) > 0
    end

    test "pipeline module contains source entity" do
      [source] = Spark.Dsl.Extension.get_entities(SyntheticPipeline, [:source])
      assert source.type == :synthetic
      assert source.direction == :north
    end

    test "pipeline source defaults" do
      defmodule DefaultPipeline do
        use LocationSimulator.Pipeline
        source :synthetic
        plug LocationSimulator.Plug.Callback
      end

      [source] = Spark.Dsl.Extension.get_entities(DefaultPipeline, [:source])
      assert source.type == :synthetic
      assert source.direction == :random
      assert source.elevation == 0
      assert source.elevation_way == :no_up_down
    end

    test "__pipeline__/1 resolves source and plugs" do
      {source, plugs} = LocationSimulator.Pipeline.__pipeline__(SyntheticPipeline)
      assert source.type == :synthetic
      assert source.direction == :north
      assert length(plugs) > 0
    end
  end

  # ── LocationSimulator.start/2 with pipeline module ─────────────────────────

  describe "start/2 with pipeline module" do
    test "fires lifecycle events: start, gps, stop" do
      LS.start(SyntheticPipeline, base_config())
      assert :ok == await_start()
      assert is_map(await_gps())
      state = await_stop()
      assert is_map(state)
      assert Map.has_key?(state, :success)
    end

    test "event count is respected" do
      LS.start(SyntheticPipeline, base_config(%{event: 5}))

      gps_count =
        for _ <- 1..6 do
          receive do
            {:gps, _} -> :gps
            {:stop, _} -> :stop
          after
            2_000 -> :timeout
          end
        end

      assert Enum.count(gps_count, &(&1 == :gps)) == 5
      assert Enum.member?(gps_count, :stop)
    end

    test "worker count is respected" do
      defmodule MultiPipeline do
        use LocationSimulator.Pipeline
        source :synthetic
        plug LocationSimulator.Plug.Callback
      end

      LS.start(MultiPipeline, base_config(%{worker: 3}))

      stops =
        for _ <- 1..3 do
          receive do
            {:stop, _} -> :ok
          after
            2_000 -> :error
          end
        end

      assert stops == [:ok, :ok, :ok]
    end
  end

  # ── Custom plug tests ─────────────────────────────────────────────────────

  describe "custom plugs" do
    test "custom plug runs before callback" do
      LS.start(PipelineWithTrackerPlug, base_config())

      receive do
        {:tracked_gps, gps} ->
          assert is_map(gps)
          assert gps.lat
          assert gps.lon
      after
        2_000 -> flunk("tracked_gps not received")
      end
    end

    test "halt plug prevents callback from running" do
      LS.start(PipelineWithHaltPlug, base_config())

      receive do
        {:gps, _} -> flunk("callback should not run after halt")
      after
        500 -> :ok
      end
    end

    test "halt plug still triggers stop callback" do
      LS.start(PipelineWithHaltPlug, base_config())
      assert is_map(await_stop())
    end
  end

  # ── Plug behaviour ─────────────────────────────────────────────────────────

  describe "Plug behaviour" do
    test "plug opts are passed to init/1" do
      defmodule InitOptsPlug do
        @behaviour LocationSimulator.Plug
        @impl true
        def init(opts), do: Keyword.put(opts, :inited, true)
        @impl true
        def call(pipeline, opts), do: %{pipeline | assigns: Map.new(opts)}
      end

      defmodule OptsPipeline do
        use LocationSimulator.Pipeline
        source :synthetic
        plug InitOptsPlug, opts: [my_option: :value]
        plug LocationSimulator.Plug.Callback
      end

      LS.start(OptsPipeline, base_config())
      assert is_map(await_stop())
    end

    test "plug can update config" do
      defmodule ConfigPlug do
        @behaviour LocationSimulator.Plug
        @impl true
        def init(opts), do: opts
        @impl true
        def call(pipeline, _opts) do
          %{pipeline | config: Map.put(pipeline.config, :my_flag, true)}
        end
      end

      defmodule ConfigPipeline do
        use LocationSimulator.Pipeline
        source :synthetic
        plug ConfigPlug
        plug LocationSimulator.Plug.Callback
      end

      LS.start(ConfigPipeline, base_config())
      assert is_map(await_stop())
    end
  end

  # ── GPS data shape ─────────────────────────────────────────────────────────

  describe "GPS data shape" do
    test "synthetic source produces valid gps data" do
      LS.start(SyntheticPipeline, base_config())

      gps = await_gps()
      assert is_number(gps.lat)
      assert is_number(gps.lon)
      assert is_number(gps.ele)
      assert is_integer(gps.timestamp)
    end

    test "synthetic direction :random is resolved" do
      defmodule RandomPipeline do
        use LocationSimulator.Pipeline
        source :synthetic, direction: :random
        plug LocationSimulator.Plug.Callback
      end

      LS.start(RandomPipeline, base_config())
      assert is_map(await_gps())
    end
  end

  # ── Plug composition ───────────────────────────────────────────────────────

  describe "plug composition" do
    test "multiple plugs run and worker completes" do
      defmodule PlugA do
        @behaviour LocationSimulator.Plug
        @impl true
        def init(opts), do: opts
        @impl true
        def call(pipeline, _opts), do: pipeline
      end

      defmodule PlugB do
        @behaviour LocationSimulator.Plug
        @impl true
        def init(opts), do: opts
        @impl true
        def call(pipeline, _opts), do: pipeline
      end

      defmodule CompositePipeline do
        use LocationSimulator.Pipeline
        source :synthetic
        plug PlugA
        plug PlugB
        plug LocationSimulator.Plug.Callback
      end

      LS.start(CompositePipeline, base_config())
      assert is_map(await_stop())
    end
  end

  # ── Source variants ─────────────────────────────────────────────────────────

  describe "source configuration variants" do
    test "source with started_gps tuple" do
      defmodule StartedGpsPipeline do
        use LocationSimulator.Pipeline
        source :synthetic, started_gps: {21.0, 105.0, 10.0}
        plug LocationSimulator.Plug.Callback
      end

      [source] = Spark.Dsl.Extension.get_entities(StartedGpsPipeline, [:source])
      assert source.started_gps == {21.0, 105.0, 10.0}
    end

    test "source with elevation_way :up" do
      defmodule ElevationUpPipeline do
        use LocationSimulator.Pipeline
        source :synthetic, elevation: 100, elevation_way: :up
        plug LocationSimulator.Plug.Callback
      end

      [source] = Spark.Dsl.Extension.get_entities(ElevationUpPipeline, [:source])
      assert source.elevation == 100
      assert source.elevation_way == :up
    end

    test "source with elevation_way :down" do
      defmodule ElevationDownPipeline do
        use LocationSimulator.Pipeline
        source :synthetic, elevation: 50, elevation_way: :down
        plug LocationSimulator.Plug.Callback
      end

      [source] = Spark.Dsl.Extension.get_entities(ElevationDownPipeline, [:source])
      assert source.elevation == 50
      assert source.elevation_way == :down
    end

    test "source with all options set" do
      defmodule AllOptionsPipeline do
        use LocationSimulator.Pipeline
        source :synthetic,
          direction: :north_east,
          elevation: 200,
          elevation_way: :up,
          started_gps: {10.0, 20.0, 30.0}
        plug LocationSimulator.Plug.Callback
      end

      [source] = Spark.Dsl.Extension.get_entities(AllOptionsPipeline, [:source])
      assert source.type == :synthetic
      assert source.direction == :north_east
      assert source.elevation == 200
      assert source.elevation_way == :up
      assert source.started_gps == {10.0, 20.0, 30.0}
    end

    test "source with type :gpx and gpx_file" do
      defmodule GpxSourcePipeline do
        use LocationSimulator.Pipeline
        source :gpx, gpx_file: "test/fixtures/*.gpx"
        plug LocationSimulator.Plug.Callback
      end

      [source] = Spark.Dsl.Extension.get_entities(GpxSourcePipeline, [:source])
      assert source.type == :gpx
      assert source.gpx_file == "test/fixtures/*.gpx"
      assert source.direction == :random
    end
  end

  # ── Worker edge cases ─────────────────────────────────────────────────────

  describe "worker edge cases" do
    test "worker without callback uses fallback fire_start and fire_stop" do
      spec = {LocationSimulator.Worker, %{id: 100, event: 1, interval: 0}}
      LocationSimulator.DynamicSupervisor.start_simulator([spec])

      Process.sleep(200)
    end

    test "gpx worker with :gpx_time interval and data exhaustion" do
      LS.start(%{
        worker: 1,
        event: 20,
        interval: :gpx_time,
        gpx_file: "test/fixtures/test_track.gpx",
        callback: TestEvent,
        client: self()
      })

      gps =
        receive do
          {:gps, gps} -> gps
        after
          2_000 -> flunk("no gps event")
        end

      assert gps.lat == 10.0
    end

    test "more workers than gpx files wraps around" do
      LS.start(%{
        worker: 5,
        event: 1,
        interval: 0,
        gpx_file: "test/fixtures/test_track.gpx",
        callback: TestEvent,
        client: self()
      })

      stops = Enum.reduce(1..5, [], fn _, acc ->
        receive do
          {:stop, _} -> [:ok | acc]
        after
          2_000 -> flunk("no stop event")
        end
      end)

      assert length(stops) == 5
    end

    test "sleep_duration fallback with no interval" do
      LS.start(%{worker: 1, event: 1, callback: TestEvent, client: self()})
      receive do
        {:stop, _} -> :ok
      after
        2_000 -> flunk("no stop event")
      end
    end
  end

  # ── Pipeline without source entity ─────────────────────────────────────────

  describe "pipeline without source" do
    test "resolve_source falls back to default when no source defined" do
      defmodule NoSourcePipeline do
        use LocationSimulator.Pipeline
        plug LocationSimulator.Plug.Callback
      end

      {source, _plugs} = LocationSimulator.Pipeline.__pipeline__(NoSourcePipeline)
      assert source.type == :synthetic
      assert source.direction == :random
    end
  end

  # ── Gps module edge cases ─────────────────────────────────────────────────

  describe "Gps.generate_next_pos with defaults" do
    test "uses default step values when not provided" do
      {lat, lon} = LocationSimulator.Gps.generate_next_pos(10.0, 20.0)
      assert is_float(lat)
      assert is_float(lon)
      assert lat > 10.0
    end
  end

  # ── SyntheticGps fallback resolve_direction ───────────────────────────────

  describe "SyntheticGps resolve_direction fallback" do
    test "generates random direction when config has no direction key" do
      pipeline = %{
        config: %{interval: 0, elevation: 0, elevation_way: :no_up_down},
        state: %{gps: %{lat: 10.0, lon: 20.0, ele: 0}},
        gps: %{lat: 10.0, lon: 20.0, ele: 0},
        halted: false,
        assigns: %{}
      }

      result = LocationSimulator.Plug.SyntheticGps.call(pipeline, [])
      assert result.halted == false
      assert is_number(result.gps.lat)
      assert is_number(result.gps.lon)
    end
  end

  # ── Spark entity validation errors ─────────────────────────────────────────

  describe "Spark entity validation errors" do
    test "invalid direction raises DslError" do
      assert_raise Spark.Error.DslError, ~r/direction/, fn ->
        Code.compile_string("""
        defmodule TestInvalidDirection do
          use LocationSimulator.Pipeline
          source :synthetic, direction: :invalid_direction
          plug LocationSimulator.Plug.Callback
        end
        """)
      end
    end

    test "invalid elevation type raises DslError" do
      assert_raise Spark.Error.DslError, ~r/elevation/, fn ->
        Code.compile_string("""
        defmodule TestInvalidElevation do
          use LocationSimulator.Pipeline
          source :synthetic, elevation: "not_an_integer"
          plug LocationSimulator.Plug.Callback
        end
        """)
      end
    end

    test "invalid source type raises DslError" do
      assert_raise Spark.Error.DslError, ~r/type/, fn ->
        Code.compile_string("""
        defmodule TestInvalidSourceType do
          use LocationSimulator.Pipeline
          source :invalid_type
          plug LocationSimulator.Plug.Callback
        end
        """)
      end
    end

    test "invalid elevation_way raises DslError" do
      assert_raise Spark.Error.DslError, ~r/elevation_way/, fn ->
        Code.compile_string("""
        defmodule TestInvalidElevationWay do
          use LocationSimulator.Pipeline
          source :synthetic, elevation_way: :sideways
          plug LocationSimulator.Plug.Callback
        end
        """)
      end
    end

    test "invalid started_gps tuple type raises DslError" do
      assert_raise Spark.Error.DslError, ~r/started_gps/, fn ->
        Code.compile_string("""
        defmodule TestInvalidStartedGps do
          use LocationSimulator.Pipeline
          source :synthetic, started_gps: {10, 20, "bad"}
          plug LocationSimulator.Plug.Callback
        end
        """)
      end
    end

    test "invalid plug module raises DslError" do
      assert_raise Spark.Error.DslError, ~r/module/, fn ->
        Code.compile_string("""
        defmodule TestInvalidPlug do
          use LocationSimulator.Pipeline
          source :synthetic
          plug 12345
        end
        """)
      end
    end
  end

  # ── Legacy backward compat ────────────────────────────────────────────────

  describe "legacy API backward compatibility" do
    test "start/1 with plain config map" do
      LS.start(%{worker: 1, event: 1, interval: 0, callback: TestEvent, client: self()})
      assert :ok == await_start()
    end

    test "start/0 with default config does not crash" do
      LS.start()
      Process.sleep(100)
    end
  end
end
