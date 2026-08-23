defmodule LocationSimulator.Gpx do
  @moduledoc """
  `Gpx` is a module that provides functions for parsing GPX file.
  """

  import SweetXml

  @doc """
  Reads a GPX file and returns the list of `%LocationSimulator.Gpx.GpsPoint{}`.

  Raises when the file cannot be read.
  """
  @spec read_gpx(Path.t()) :: [LocationSimulator.Gpx.GpsPoint.t()]
  def read_gpx(file) do
    case File.read(file) do
      {:ok, content} ->
        parse_gpx_content(content)

      {:error, reason} ->
        raise "cannot read file #{inspect(file)}, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Parses GPX content and returns the list of `%LocationSimulator.Gpx.GpsPoint{}`.
  """
  @spec read_string_gpx(String.t()) :: [LocationSimulator.Gpx.GpsPoint.t()]
  def read_string_gpx(content) do
    parse_gpx_content(content)
  end

  @doc """
  Expands a GPX glob pattern to matching files.

  Raises when nothing matches, so misconfiguration fails fast.
  """
  @spec resolve_files!(String.t()) :: [Path.t()]
  def resolve_files!(pattern) do
    case Path.wildcard(pattern) do
      [] -> raise "No GPX files matched: #{inspect(pattern)}"
      files -> files
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
      lat: xpath(xml_el, ~x"./@lat"f),
      lon: xpath(xml_el, ~x"./@lon"f),
      # ~x"F" is SweetXml's soft float: missing or invalid <ele> becomes 0.0
      ele: xpath(xml_el, ~x"./ele/text()"F),
      time: xml_el |> xpath(~x"./time/text()"s) |> parse_datetime()
    }
  end

  defp parse_datetime(str) do
    case NaiveDateTime.from_iso8601(str) do
      {:ok, datetime} -> datetime
      {:error, _reason} -> nil
    end
  end
end
