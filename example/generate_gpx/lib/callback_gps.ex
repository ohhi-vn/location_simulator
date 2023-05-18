defmodule GenerateGpx.GpxWriter do
  @moduledoc """
  Generates a GPX file. Gps data is single waypoint with series of track points.
  """
  @behaviour LocationSimulator.Event

  require Logger

  ## Callbacks ##

  @impl true
  def start(%{file: file} = config, _state) do
    time = DateTime.utc_now()
    header = """
    <?xml version="1.0"?>
    <gpx xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.topografix.com/GPX/1/0" version="1.0" creator="GPSBabel - http://www.gpsbabel.org" xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd">
    <time>#{DateTime.to_string(time)}</time>
    <trk>
    <name>Location Simulator LOG</name>
    <trkseg>
    """
    case File.write(file, header, [:write]) do
      :ok ->
        {:ok, config}
      {:error, _reason} = failed ->
        failed
    end
  end

  @impl true
  def event(%{file: file} = config, %{gps: gps} = _state) do
    time = DateTime.utc_now()
    str = ~s(<trkpt lat="#{gps.lati}" lon="#{gps.long}"><ele>#{gps.alti}</ele><time>#{DateTime.to_string(time)}</time></trkpt>\n)

    case File.write(file, str, [:append]) do
      :ok ->
        {:ok, config}
      {:error, _reason} = failed ->
        failed
    end
  end

  @impl true
  def stop(%{file: file} = config, _state) do
    footer = """
    </trkseg></trk>
    </gpx>
    """
    case File.write(file, footer, [:append]) do
      :ok ->
        {:ok, config}
      {:error, _reason} = failed ->
        failed
    end
  end
end
