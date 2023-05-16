defmodule PrintConsoleTest do
  use ExUnit.Case
  doctest PrintConsole

  test "greets the world" do
    assert PrintConsole.hello() == :world
  end
end
