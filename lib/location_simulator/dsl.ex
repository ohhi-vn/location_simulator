defmodule LocationSimulator.Dsl do
  @moduledoc """
  Spark DSL extension defining `source` and `plug` entities for GPS pipelines.

  ## Sections

  ### `source`
  A singleton entity declaring the GPS data origin.

      source :synthetic, direction: :north, elevation: 100
      source :gpx, gpx_file: "data/*.gpx"

  ### `plugins`
  Zero or more plug modules that run per event.

      plug LocationSimulator.Plug.Callback, callback: MyApp.Handler
  """

  alias Spark.Builder.{Entity, Section}

  @source Entity.new(:source, LocationSimulator.Dsl.Source,
            describe: "The GPS data source",
            args: [:type],
            schema: [
              type: [
                type: {:one_of, [:synthetic, :gpx]},
                required: true,
                doc: "Source type: `:synthetic` generates fake GPS; `:gpx` replays GPX tracks"
              ],
              direction: [
                type:
                  {:one_of,
                   [
                     :north,
                     :south,
                     :east,
                     :west,
                     :north_east,
                     :north_west,
                     :south_east,
                     :south_west,
                     :random
                   ]},
                default: :random,
                doc: "Travel direction (synthetic only)"
              ],
              elevation: [
                type: :integer,
                default: 0,
                doc: "Starting elevation in metres (synthetic only)"
              ],
              elevation_way: [
                type: {:one_of, [:up, :down, :no_up_down]},
                default: :no_up_down,
                doc: "Elevation change direction (synthetic only)"
              ],
              started_gps: [
                type: {:tuple, [:float, :float, :float]},
                doc: "Fixed starting coordinate {lat, lon, ele}"
              ],
              gpx_file: [
                type: :string,
                doc: "Glob pattern for GPX files (gpx source only)"
              ]
            ]
          )
          |> Entity.build!()

  @plug Entity.new(:plug, LocationSimulator.Dsl.Plugin,
          describe: "A plug module included in the runtime pipeline",
          args: [:module],
          schema: [
            module: [
              type: {:behaviour, LocationSimulator.Plug},
              required: true,
              doc: "The plug module (must implement `LocationSimulator.Plug` behaviour)"
            ],
            opts: [
              type: :any,
              default: [],
              doc: "Options passed to `c:LocationSimulator.Plug.init/1`"
            ]
          ]
        )
        |> Entity.build!()

  @sections [
    Section.new(:source,
      describe: "GPS data source configuration",
      entities: [@source],
      singleton_entity_keys: [:type],
      top_level?: true
    )
    |> Section.build!(),
    Section.new(:plugins,
      describe: "Event-processing plugs in execution order",
      entities: [@plug],
      top_level?: true
    )
    |> Section.build!()
  ]

  use Spark.Dsl.Extension, sections: @sections
end
