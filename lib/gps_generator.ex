defmodule LocationSimulator.Gps do
  @moduledoc """
  Generate a random location. Get next gps from a location.
  """

  require Logger
  require Math

  @doc """
  Generates a random location.
  """
  def generate_pos() do
    Random.seed(System.monotonic_time(:nanosecond))
    {Random.uniform(-90,90), Random.uniform(-180, 180)}
  end

  @doc """
  Gets next location from current location.
  """
  def generate_next_pos(lati, long, step_lati \\1, step_long \\ 1) when is_number(long) and is_number(lati) do
    new_lati = lati + (step_lati * meter_in_degree())
    new_long = long + (step_long * meter_in_degree()) / Math.cos(lati * (Math.pi()/180))
    {new_lati,  new_long}
  end

  defp meter_in_degree() do
    # Radius of the earth (km)
    earth_radius = 6378.137
    pi = Math.pi()
    r = (2 * pi) / 360
    r = 1 / (r * earth_radius)
    r / 1000
  end

end
