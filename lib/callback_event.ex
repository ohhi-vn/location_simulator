defmodule LocationSimulator.Event do
  @callback start(config :: map, state :: map) :: {:ok, map} | {:error, reason :: any}
  @callback event(config :: map, state :: map) :: {:ok, map} | {:error, reason :: any} | {:stop, reason :: any}
  @callback stop(config :: map, state :: map) :: {:ok, map} | {:error, reason :: any}
end
