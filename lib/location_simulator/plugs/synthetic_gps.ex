defmodule LocationSimulator.Plug.SyntheticGps do
  @moduledoc """
  Generates the next synthetic GPS point in the current direction.

  Expects `config.direction` to be a resolved direction atom. A direction of
  `:random` (or a missing `:direction` key) is resolved once and then fixed
  for the worker's lifetime — the worker travels consistently in one direction.

  Handles both coordinate movement and elevation changes.
  """

  @behaviour LocationSimulator.Plug

  import LocationSimulator.Gps

  @directions [:north, :south, :east, :west, :north_east, :north_west, :south_east, :south_west]

  @impl true
  def init(opts), do: opts

  @impl true
  def call(pipeline, _opts) do
    %{config: config, state: state, gps: last_gps} = pipeline

    config = resolve_direction(config)

    gps = generate_next_gps(config, last_gps)

    %{pipeline | config: config, state: %{state | gps: gps}, gps: gps}
  end

  # A fixed direction is kept; anything else (:random or missing) is resolved once.
  defp resolve_direction(%{direction: dir} = config) when dir != :random, do: config

  defp resolve_direction(config) do
    Map.put(config, :direction, Enum.random(@directions))
  end

  defp generate_next_gps(config, last_gps) do
    dir = config.direction

    {lat, lon} =
      generate_next_pos(
        last_gps.lat,
        last_gps.lon,
        lat_step(dir),
        lon_step(dir)
      )

    ele = next_elevation(config, last_gps.ele)

    now = :os.system_time(:millisecond)
    %{lat: lat, lon: lon, ele: ele, timestamp: now}
  end

  defp next_elevation(%{elevation_way: :up}, ele), do: ele + Enum.random(0..2)
  defp next_elevation(%{elevation_way: :down}, ele), do: ele - Enum.random(0..2)
  defp next_elevation(_, ele), do: ele

  defp lon_step(dir) do
    cond do
      dir in [:north_east, :south_east, :east] -> Enum.random(1..5)
      dir in [:north_west, :south_west, :west] -> Enum.random(-5..-1//1)
      true -> 0
    end
  end

  defp lat_step(dir) do
    cond do
      dir in [:north_east, :north_west, :north] -> Enum.random(1..5)
      dir in [:south_east, :south_west, :south] -> Enum.random(-5..-1//1)
      true -> 0
    end
  end
end
