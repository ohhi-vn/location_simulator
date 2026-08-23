defmodule LocationSimulatorTest do
  use ExUnit.Case, async: false

  alias LocationSimulator, as: LS
  alias :ets, as: Ets

  # ── Shared test callback ───────────────────────────────────────────────────

  defmodule TestEvent do
    @behaviour LocationSimulator.Event

    alias :ets, as: Ets

    @impl true
    def start(config, state) do
      notify(config, {:start, state})

      case Map.get(config, :test) do
        :start_error ->
          {:error, "intentional start error"}

        :count_start ->
          Ets.update_counter(LocationSimulatorTest, :started, 1)
          {:ok, config}

        _ ->
          {:ok, config}
      end
    end

    @impl true
    def event(config, %{gps: gps} = _state) do
      notify(config, {:gps, gps})

      case Map.get(config, :test) do
        :failed -> {:error, "intentional failure"}
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

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp base_config(overrides \\ %{}) do
    Map.merge(
      %{worker: 1, event: 1, interval: 0, random_range: 0, callback: TestEvent, client: self()},
      overrides
    )
  end

  defp await(pattern, timeout \\ 2_000) do
    receive do
      ^pattern -> :ok
      {^pattern, _} -> :ok
    after
      timeout -> {:error, :timeout}
    end
  end

  defp collect(tag, count, timeout \\ 2_000) do
    Enum.reduce_while(1..count, [], fn _, acc ->
      receive do
        {^tag, data} -> {:cont, [data | acc]}
      after
        timeout -> {:halt, acc}
      end
    end)
    |> Enum.reverse()
  end

  # ── ETS setup ─────────────────────────────────────────────────────────────

  setup_all do
    Ets.new(__MODULE__, [:set, :public, :named_table])
    :ok
  end

  setup do
    Ets.delete_all_objects(__MODULE__)
    :ok
  end

  # ── default_config/0 ──────────────────────────────────────────────────────

  describe "default_config/0" do
    test "returns a map" do
      assert is_map(LS.default_config())
    end

    test "contains all required keys" do
      config = LS.default_config()

      required = [
        :worker,
        :event,
        :interval,
        :random_range,
        :direction,
        :elevation,
        :elevation_way,
        :callback
      ]

      for key <- required do
        assert Map.has_key?(config, key), "missing key #{inspect(key)}"
      end
    end

    test "default worker count is 1" do
      assert LS.default_config().worker == 1
    end

    test "default callback is LoggerEvent" do
      assert LS.default_config().callback == LocationSimulator.LoggerEvent
    end
  end

  # ── Lifecycle events ──────────────────────────────────────────────────────

  describe "lifecycle events" do
    test "start event fires" do
      LS.start(base_config())
      assert :ok == await(:start)
    end

    test "stop event fires" do
      LS.start(base_config())
      assert :ok == await(:stop)
    end

    test "gps event fires" do
      LS.start(base_config())
      assert :ok == await(:gps)
    end

    test "start then gps then stop ordering" do
      LS.start(base_config(%{event: 2}))

      order =
        for _ <- 1..4 do
          receive do
            {:start, _} -> :start
            {:gps, _} -> :gps
            {:stop, _} -> :stop
          after
            2_000 -> :timeout
          end
        end

      assert [:start, :gps, :gps, :stop] == order
    end
  end

  # ── Error / stop semantics ────────────────────────────────────────────────

  describe "callback return values" do
    test "start returning :error prevents gps events" do
      LS.start(base_config(%{test: :start_error}))

      result =
        receive do
          {:gps, _} -> :received_gps
        after
          500 -> :no_gps
        end

      assert :no_gps == result
    end

    test "event returning :error increments failed counter" do
      events = 10
      LS.start(base_config(%{event: events, test: :failed}))

      state =
        receive do
          {:stop, s} -> s
        after
          2_000 -> flunk("no stop event received")
        end

      assert state.failed == events
      assert state.success == 0
    end

    test "event returning :stop halts worker early" do
      events = 20
      LS.start(base_config(%{event: events, test: :stop}))

      state =
        receive do
          {:stop, s} -> s
        after
          2_000 -> flunk("no stop event received")
        end

      assert state.success < events
    end

    test "event returning :ok increments success counter" do
      events = 15
      LS.start(base_config(%{event: events}))

      state =
        receive do
          {:stop, s} -> s
        after
          2_000 -> flunk("no stop event received")
        end

      assert state.success == events
      assert state.failed == 0
    end
  end

  # ── Multiple workers ──────────────────────────────────────────────────────

  describe "multiple workers" do
    test "correct number of workers start" do
      n = 8
      Ets.insert(__MODULE__, {:started, 0})

      LS.start(base_config(%{worker: n, test: :count_start}))
      Process.sleep(500)

      [{_, started}] = Ets.lookup(__MODULE__, :started)
      assert started == n
    end

    test "each worker emits its own stop event" do
      n = 5
      LS.start(base_config(%{worker: n}))

      stops = collect(:stop, n)
      assert length(stops) == n
    end
  end

  # ── GPS data shape ────────────────────────────────────────────────────────

  describe "GPS data shape" do
    test "gps point has required keys" do
      LS.start(base_config())

      receive do
        {:gps, gps} ->
          for key <- [:lat, :lon, :ele, :timestamp] do
            assert Map.has_key?(gps, key), "gps missing key #{inspect(key)}"
          end
      after
        2_000 -> flunk("no gps event received")
      end
    end

    test "gps coordinates are numbers" do
      LS.start(base_config())

      receive do
        {:gps, gps} ->
          assert is_number(gps.lat)
          assert is_number(gps.lon)
          assert is_number(gps.ele)
      after
        2_000 -> flunk("no gps event received")
      end
    end

    test "gps timestamp increases monotonically" do
      LS.start(base_config(%{event: 5, interval: 1}))
      points = collect(:gps, 5)

      timestamps = Enum.map(points, & &1.timestamp)
      assert timestamps == Enum.sort(timestamps)
    end
  end

  # ── Direction / elevation ─────────────────────────────────────────────────

  describe "direction config" do
    for dir <- [:north, :south, :east, :west, :north_east, :north_west, :south_east, :south_west] do
      test "direction #{dir} produces gps events" do
        LS.start(base_config(%{direction: unquote(dir), event: 3}))
        assert :ok == await(:gps)
      end
    end

    test "direction :random produces gps events" do
      LS.start(base_config(%{direction: :random, event: 3}))
      assert :ok == await(:gps)
    end
  end

  describe "elevation config" do
    test ":up increases elevation over time" do
      LS.start(base_config(%{event: 10, interval: 0, elevation: 100, elevation_way: :up}))
      points = collect(:gps, 10)
      eles = Enum.map(points, & &1.ele)
      assert List.last(eles) >= hd(eles)
    end

    test ":down decreases elevation over time" do
      LS.start(base_config(%{event: 10, interval: 0, elevation: 100, elevation_way: :down}))
      points = collect(:gps, 10)
      eles = Enum.map(points, & &1.ele)
      assert List.last(eles) <= hd(eles)
    end
  end

  # ── started_gps ───────────────────────────────────────────────────────────

  describe "started_gps" do
    test "first gps point matches configured start position" do
      lat = 21.0278
      lon = 105.8342

      LS.start(base_config(%{event: 1, started_gps: {lat, lon, 0.0}}))

      gps =
        receive do
          {:gps, gps} -> gps
        after
          2_000 -> flunk("no gps event received")
        end

      # First event moves one step (a few metres) from the seeded position.
      assert abs(gps.lat - lat) < 0.001
      assert abs(gps.lon - lon) < 0.001
      assert gps.ele == 0.0
    end
  end

  # ── Group stop ────────────────────────────────────────────────────────────

  describe "group stop" do
    test "stop/1 halts all workers in the group before event count exhausted" do
      group = :test_group
      n = 4

      LS.start(
        base_config(%{
          worker: n,
          event: :infinity,
          interval: 50,
          group_id: group
        })
      )

      Process.sleep(200)
      LS.stop(group)

      stops = collect(:stop, n, 3_000)
      assert length(stops) == n
    end
  end

  # ── state completeness ────────────────────────────────────────────────────

  describe "stop state" do
    test "stop state contains start_time, stop_time, success, failed" do
      LS.start(base_config(%{event: 3}))

      state =
        receive do
          {:stop, s} -> s
        after
          2_000 -> flunk("no stop event received")
        end

      for key <- [:start_time, :stop_time, :success, :failed] do
        assert Map.has_key?(state, key), "stop state missing #{inspect(key)}"
      end
    end

    test "stop_time >= start_time" do
      LS.start(base_config())

      state =
        receive do
          {:stop, s} -> s
        after
          2_000 -> flunk("no stop event received")
        end

      assert state.stop_time >= state.start_time
    end
  end

  # ── GPX file start ────────────────────────────────────────────────────────

  describe "start/1 with gpx_file" do
    test "parses gpx file and replays points" do
      LS.start(%{
        worker: 1,
        event: 3,
        interval: 0,
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
      assert gps.lon == 20.0
    end

    test "distributes multiple files across workers" do
      LS.start(%{
        worker: 2,
        event: 1,
        interval: 0,
        gpx_file: "test/fixtures/*.gpx",
        callback: TestEvent,
        client: self()
      })

      lats =
        for _ <- 1..2 do
          receive do
            {:gps, gps} -> gps.lat
          after
            2_000 -> flunk("no gps event")
          end
        end

      # Worker 1 replays the first fixture, worker 2 the second.
      assert Enum.sort(lats) == [10.0, 30.0]
    end

    test "raises when glob matches no files" do
      assert_raise RuntimeError, ~r/No GPX files matched/, fn ->
        LS.start(%{worker: 1, event: 1, interval: 0, gpx_file: "test/fixtures/nope_*.gpx"})
      end
    end

    test "interval :gpx_time with started_gps sleeps 0 before first point" do
      LS.start(%{
        worker: 1,
        event: 1,
        interval: :gpx_time,
        gpx_file: "test/fixtures/test_track.gpx",
        started_gps: {10.0, 20.0, 5.0},
        callback: TestEvent,
        client: self()
      })

      gps =
        receive do
          {:gps, gps} -> gps
        after
          2_000 -> flunk("no gps event")
        end

      # The replayed point comes from the track; started_gps only seeds timing.
      assert gps.lat == 10.0
      assert :ok == await(:stop)
    end
  end

  # ── DynamicSupervisor ─────────────────────────────────────────────────────

  describe "LocationSimulator.DynamicSupervisor" do
    test "start_simulator with spec without :id uses self()" do
      spec =
        {LocationSimulator.Worker,
         %{callback: TestEvent, client: self(), worker: 1, event: 1, interval: 0}}

      LocationSimulator.DynamicSupervisor.start_simulator([spec])

      assert :ok == await(:stop)
    end

    test "start_link/1 delegates to OTP DynamicSupervisor" do
      assert {:error, {:already_started, _pid}} =
               LocationSimulator.DynamicSupervisor.start_link(:ok)
    end

    test "init/1 returns DynamicSupervisor init tuple" do
      assert {:ok, %{strategy: :one_for_one, intensity: _, period: _, max_children: _}} =
               LocationSimulator.DynamicSupervisor.init(:ok)
    end

    test "start_simulator raises for invalid child spec" do
      assert_raise FunctionClauseError, fn ->
        LocationSimulator.DynamicSupervisor.start_simulator([
          {LocationSimulator.Worker, "not a map"}
        ])
      end
    end

    test "start_simulator propagates child start errors" do
      defmodule FailingWorker do
        def child_spec(_opts) do
          %{
            id: __MODULE__,
            start: {__MODULE__, :start_link, []},
            type: :worker,
            restart: :temporary
          }
        end

        def start_link, do: {:error, :nope}
      end

      assert {:error, :nope} =
               LocationSimulator.DynamicSupervisor.start_simulator([{FailingWorker, []}])
    end
  end

  # ── Worker edge cases ─────────────────────────────────────────────────────

  describe "worker gpx selection without :id" do
    test "worker without :id loads the first matched file" do
      spec = {
        LocationSimulator.Worker,
        %{
          event: 1,
          interval: 0,
          gpx_file: "test/fixtures/*.gpx",
          callback: TestEvent,
          client: self()
        }
      }

      LocationSimulator.DynamicSupervisor.start_simulator([spec])

      gps =
        receive do
          {:gps, gps} -> gps
        after
          2_000 -> flunk("no gps event")
        end

      assert gps.lat == 10.0
    end
  end

  describe "stop callback failures" do
    test "stop returning :error crashes the worker after firing stop" do
      defmodule StopFailEvent do
        @behaviour LocationSimulator.Event

        @impl true
        def start(config, _state), do: {:ok, config}

        @impl true
        def event(config, _state), do: {:ok, config}

        @impl true
        def stop(config, state) do
          if client = Map.get(config, :client), do: send(client, {:stop_called, state})
          {:error, :boom}
        end
      end

      LS.start(base_config(%{callback: StopFailEvent}))

      assert_receive {:stop_called, _state}, 2_000
    end
  end

  # ── Runtime application config ────────────────────────────────────────────

  describe "default_config/0 reads runtime application env" do
    test "reflects application env set after compilation" do
      Application.put_env(:location_simulator, :default_config,
        worker: 7,
        callback: __MODULE__.TestEvent
      )

      on_exit(fn -> Application.delete_env(:location_simulator, :default_config) end)

      config = LS.default_config()
      assert config.worker == 7
      assert config.callback == TestEvent
      # unset keys fall back to built-in defaults
      assert config.event == 1
    end
  end
end
