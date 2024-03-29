defmodule LocationSimulator.Gpx.GpsPoint do
  @moduledoc """
  `GpsPoint` is a struct that represents a GPS point load from GPX file.
  """

  @typedoc """
  Holds GPS point data from GPX file.
  `:lati` is latitude.
  `:long` is longitude.
  `:elev` is elevation.
  `:time` is time of GPS point.
  """
  @type t :: %__MODULE__{
          lati: float,
          long: float,
          elev: float,
          time: NaiveDateTime.t | nil
        }
  defstruct [
    :lati,
    :long,
    :elev,
    :time
  ]
end
