defmodule LocationSimulator.Gps do
  @moduledoc """
  Generate a random location. Get next gps from a location.
  """

  alias :math, as: Math

  # Radius of the earth (km)
  @earth_radius_km 6378.137

  # Degrees per metre at the equator.
  @meter_in_degree 1 / (2 * Math.pi() / 360 * @earth_radius_km) / 1000

  @doc """
  Generates a random location as `{lat, lon}` floats.
  """
  @spec generate_pos :: {float(), float()}
  def generate_pos do
    {:rand.uniform(90) * 1.0, :rand.uniform(180) * 1.0}
  end

  @doc """
  Gets next location from current location.

  Steps are in metres; longitude step is corrected by latitude (cos factor).
  """
  @spec generate_next_pos(float, float, number, number) :: {float, float}
  def generate_next_pos(lati, long, step_lati \\ 1, step_long \\ 1)
      when is_number(long) and is_number(lati) do
    new_lati = lati + step_lati * @meter_in_degree
    new_long = long + step_long * @meter_in_degree / Math.cos(lati * (Math.pi() / 180))
    {new_lati, new_long}
  end
end
