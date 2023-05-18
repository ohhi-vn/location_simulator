defmodule GenerateGpx do
  @moduledoc """
  This is an example for use LocationSimulator.

  The Example will generate a GPX file that contains GPS data.
  """

  alias LocationSimulator, as: LS

  @doc """
  Generate a GPX file.

  ## Examples

      iex> GenerateGpx.gen_gpx("fake_gps.gpx")

  """
  def gen_gpx(file_path \\ "test.gpx", event \\ 10) do
    config = %{
      # Lib config
      worker: 1,
      event: event,
      interval: 0,
      random_range: 0,
      callback: GenerateGpx.GpxWriter,

      # App config
      file: file_path
    }

    LS.start(config)
  end
end
