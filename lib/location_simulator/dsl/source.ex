defmodule LocationSimulator.Dsl.Source do
  @moduledoc """
  DSL entity representing a GPS data source.

  Injected at compile time via `source` inside a `use LocationSimulator.Pipeline` module.
  """
  defstruct [
    :type,
    :direction,
    :elevation,
    :elevation_way,
    :gpx_file,
    :started_gps,
    :__spark_metadata__
  ]
end
