defmodule LocationSimulator.Pipeline do
  @moduledoc """
  Declares a composable GPS simulation pipeline using Spark DSL.

  ## Usage

      defmodule MyApp.TaxiFleet do
        use LocationSimulator.Pipeline

        source :synthetic, direction: :north, elevation: 50

        plug LocationSimulator.Plug.Callback, callback: MyApp.TaxiHandler
      end

  Then start workers at runtime:

      LocationSimulator.start(MyApp.TaxiFleet, worker: 3, event: 100, interval: 1_000)

  ## Default pipeline

  If you want the legacy behaviour (no explicit pipeline module), pass a plain
  config map instead:

      LocationSimulator.start(%{worker: 3, callback: MyApp.Handler})
  """

  use Spark.Dsl,
    default_extensions: [extensions: [LocationSimulator.Dsl]]

  @doc false
  def __pipeline__(module) do
    source = resolve_source(module)
    plugs = resolve_plugs(module)
    {source, plugs}
  end

  defp resolve_source(module) do
    case Spark.Dsl.Extension.get_entities(module, [:source]) do
      [source] -> source
      [] -> %LocationSimulator.Dsl.Source{type: :synthetic, direction: :random}
    end
  end

  defp resolve_plugs(module) do
    module
    |> Spark.Dsl.Extension.get_entities([:plugins])
    |> Enum.map(fn %{module: mod, opts: opts} ->
      {mod, mod.init(opts)}
    end)
  end
end
