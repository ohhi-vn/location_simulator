defmodule LocationSimulator.Plug.SleepTest do
  use ExUnit.Case, async: true

  alias LocationSimulator.Plug.Sleep

  describe "init/1" do
    test "returns opts as-is" do
      assert Sleep.init([]) == []
      assert Sleep.init(%{}) == %{}
      assert Sleep.init([key: :value]) == [key: :value]
    end
  end

  describe "call/2" do
    test "sleeps for config.interval and stores sleep_ms in state" do
      pipeline = %{
        config: %{interval: 1},
        state: %{},
        gps: nil,
        halted: false,
        assigns: %{}
      }

      {time, result} = :timer.tc(fn -> Sleep.call(pipeline, []) end)

      assert time >= 1000
      assert result.state.sleep_ms == 1
      assert result.halted == false
    end

    test "sleeps for interval + random_range jitter" do
      pipeline = %{
        config: %{interval: 1, random_range: 5},
        state: %{},
        gps: nil,
        halted: false,
        assigns: %{}
      }

      {time, result} = :timer.tc(fn -> Sleep.call(pipeline, []) end)

      assert time >= 1000
      assert result.state.sleep_ms >= 1
      assert result.state.sleep_ms <= 6
    end

    test "defaults random_range to 0 when not in config" do
      pipeline = %{
        config: %{interval: 1},
        state: %{},
        gps: nil,
        halted: false,
        assigns: %{}
      }

      result = Sleep.call(pipeline, [])
      assert result.state.sleep_ms == 1
    end
  end
end
