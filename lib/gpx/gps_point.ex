defmodule LocationSimulator.Gpx.GpsPoint do
  @moduledoc """
  `GpsPoint` is a struct that represents a GPS point load from GPX file.
  """

  @typedoc """
  Holds GPS point data from GPX file.
  `:lat` is latitude.
  `:lon` is longitude.
  `:ele` is elevation.
  `:time` is time of GPS point.
  """
  @type t :: %__MODULE__{
          lat: float,
          lon: float,
          ele: float,
          time: DateTime.t | nil
        }
  defstruct [
    :lat,
    :lon,
    :ele,
    :time
  ]
end
