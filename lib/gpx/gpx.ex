defmodule LocationSimulator.Gpx do
  @moduledoc """
  `Gpx` is a module that provides functions for parsing GPX file.
  """

  import SweetXml

  ## Public functions ##
  def read_gpx(file) do
    parse_gpx(file)
  end

  def read_string_gpx(content) do
    parse_gpx_content(content)
  end

  ## Private functions ##

  defp parse_gpx(file) do
    case File.read(file) do
      {:ok, content} ->
        parse_gpx_content(content)
      {:error, reason} ->
        raise "cannot read file #{inspect file}, reason: #{inspect reason}"
    end
  end

  defp parse_gpx_content(content) do
    content
    |> parse()
    |> xpath(~x"//trkseg/trkpt"l)
    |> Enum.map(&parse_gpx_point/1)
  end

  defp parse_gpx_point(xml_el) do
    %LocationSimulator.Gpx.GpsPoint{
      lati: xml_el |> xpath(~x"./@lat"f) ,
      long: xml_el |> xpath(~x"./@lon"f),
      elev: xml_el |> xpath(~x"./ele/text()"f),
      time: xml_el |> xpath(~x"./time/text()"s) |> parse_datetime()
    }
  end

  defp parse_datetime(str) do
    case NaiveDateTime.from_iso8601(str) do
      {:ok, datetime} -> datetime
      {:error, _seasion} -> nil
    end
  end
end
