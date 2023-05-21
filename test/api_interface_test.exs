
defmodule LocationSimulatorTest.TestEvent do
  @moduledoc """
  Default callback for demo & develop.

  Just get data from `LocationSimulator.Worker` and print to console (by Logger).
  """

  @behaviour LocationSimulator.Event

  alias :ets, as: Ets

  require Logger

  @impl true
  def start(config, state) do
    client = Map.get(config, :client)
    send(client, {:start, state})
    case Map.get(config, :test) do
      :test_start_error ->
        {:error, "test return error from start event"}
      :count_worker ->
        [{_, counter}] = Ets.lookup(LocationSimulatorTest, :started)
        Ets.insert(LocationSimulatorTest, {:started, counter + 1})
        {:ok, config}
      _ ->
        {:ok, config}
    end
  end

  @impl true
  def event(config, %{gps: gps} = _state) do
    client = Map.get(config, :client)
    send(client, {:gps, gps})

    case Map.get(config, :test) do
      :failed ->
        {:error, "test error return by client"}
      :stop ->
        {:stop, "test stop by client"}
      _ ->
        {:ok, config}
    end
  end

  @impl true
  def stop(config, state) do
    client = Map.get(config, :client)
    send(client, {:stop, state})

    {:ok, config}
  end
end


defmodule LocationSimulatorTest do
  use ExUnit.Case
  doctest LocationSimulator

  alias LocationSimulator, as: LS
  alias :ets, as: Ets

  require Logger

  setup_all do
    Ets.new(
      __MODULE__,
      [:set, :public, :named_table]
    )

    :ok
  end

  setup do
    Ets.delete_all_objects(__MODULE__)

    :ok
  end

  test "default config" do
    config = LocationSimulator.default_config()
    assert is_map(config)
  end

  test "catch start event" do
    config = %{
      # Lib config
      worker: 1,
      event: 1,
      interval: 0,
      random_range: 0,
      callback:  LocationSimulatorTest.TestEvent,

      # App config
      test: :start,
      client: self()
    }

    LS.start(config)

    result =
      receive do
        {:start, _} ->
          :ok
        after 1000 ->
          :failed
      end

    assert :ok == result
  end

  test "return :error in start event" do
    config = %{
      # Lib config
      worker: 1,
      event: 1,
      interval: 0,
      random_range: 0,
      callback:  LocationSimulatorTest.TestEvent,

      # App config
      test: :test_start_error,
      client: self()
    }

    LS.start(config)

    result =
      receive do
        {:gps, _} ->
          :failed
        after 1000 ->
          :ok
      end

    assert :ok == result
  end

  test "catch stop event" do
    config = %{
      # Lib config
      worker: 1,
      event: 1,
      interval: 0,
      random_range: 0,
      callback:  LocationSimulatorTest.TestEvent,

      # App config
      test: :start,
      client: self()
    }

    LS.start(config)

    result =
      receive do
        {:stop, _} ->
          :ok
        after 1000 ->
          :failed
      end

    assert :ok == result
  end

  test "catch gps event" do
    config = %{
      # Lib config
      worker: 1,
      event: 1,
      interval: 0,
      random_range: 0,
      callback:  LocationSimulatorTest.TestEvent,

      # App config
      test: :start,
      client: self()
    }

    LS.start(config)

    result =
      receive do
        {:gps, _} ->
          :ok
        after 1000 ->
          :failed
      end

    assert :ok == result
  end

  test "count success event" do
    event = 15
    config = %{
      # Lib config
      worker: 1,
      event: event,
      interval: 0,
      random_range: 0,
      callback:  LocationSimulatorTest.TestEvent,

      # App config
      test: :success,
      client: self()
    }

    LS.start(config)

    result =
      receive do
        {:stop, state} ->
          Map.get(state, :success, -1)
        after 1000 ->
          :failed
      end

    assert event == result
  end

  test "count failed event" do
    event = 15
    config = %{
      # Lib config
      worker: 1,
      event: event,
      interval: 0,
      random_range: 0,
      callback:  LocationSimulatorTest.TestEvent,

      # App config
      test: :failed,
      client: self()
    }

    LS.start(config)

    result =
      receive do
        {:stop, state} ->
          Map.get(state, :failed, -1)
        after 1000 ->
          :failed
      end

    assert event == result
  end

  test "count stop by client event" do
    event = 15
    config = %{
      # Lib config
      worker: 1,
      event: event,
      interval: 0,
      random_range: 0,
      callback:  LocationSimulatorTest.TestEvent,

      # App config
      test: :stop,
      client: self()
    }

    LS.start(config)

    result =
      receive do
        {:stop, state} ->
          Map.get(state, :success, -1)
        after 1000 ->
          :failed
      end

    assert event > result
  end

  test "count worker" do
    worker = 10
    config = %{
      # Lib config
      worker: worker,
      event: 1,
      interval: 0,
      random_range: 0,
      callback:  LocationSimulatorTest.TestEvent,

      # App config
      test: :count_worker,
      client: self()
    }

    Ets.insert(__MODULE__, {:started, 0})

    LS.start(config)

    # waiting for all worker started.
    Process.sleep(3000)

    [{_, started}] = Ets.lookup(__MODULE__, :started)

    assert worker == started
  end

end
