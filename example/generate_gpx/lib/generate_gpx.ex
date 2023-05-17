defmodule GenerateGpx do
  @moduledoc """
  Documentation for `GenerateGpx`.
  """

  alias LocationSimulator, as: LS

  @doc """
  Hello world.

  ## Examples

      iex> GenerateGpx.hello()
      :world

  """
  def gen_gpx(file_path \\ "test.gpx") do
    config = %{
      # Lib config
      worker: 1,
      event: 10,
      interval: 300,
      random_range: 10,
      callback: LocationSimulator.GpxWriter,

      # App config
      file: file_path
    }

    LS.start(config)
  end
end
