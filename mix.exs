defmodule LocationSimulator.MixProject do
  use Mix.Project

  def project do
    [
      app: :location_simulator,
      version: "1.0.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Docs
      name: "LocationSimulator",
      source_url: "https://github.com/ohhi-vn/location_simulator",
      homepage_url: "https://ohhi.vn",
      docs: docs(),
      description: description(),
      package: package(),

      # Paths
      elixirc_paths: elixirc_paths(Mix.env()),

      # Test
      test_paths: ["test"],
      test_load_filters: [&String.ends_with?(&1, "_test.exs")],
      test_ignore_filters: [&String.starts_with?(&1, "test/support/")],
      test_coverage: [
        tool: Mix.Tasks.Test.Coverage,
        output: "cover",
        summary: [threshold: 80]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      mod: {LocationSimulator.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:spark, "~> 2.7"},
      {:sweet_xml, "~> 0.7"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description do
    "A pluggable GPS location simulator for Elixir. Generate synthetic GPS data or replay GPX tracks for dev/test."
  end

  defp package do
    [
      maintainers: ["Manh Vu"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/ohhi-vn/location_simulator",
        "About us" => "https://ohhi.vn"
      },
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* guides)
    ]
  end

  defp docs do
    [
      main: "LocationSimulator",
      extras: [
        "README.md",
        "guides/getting_started.md",
        "guides/architecture.md",
        "guides/writing_plugs.md",
        "guides/gpx_replay.md"
      ],
      groups_for_modules: [
        Pipeline: [
          LocationSimulator.Pipeline,
          LocationSimulator.Plug,
          LocationSimulator.Dsl,
          LocationSimulator.Dsl.Source,
          LocationSimulator.Dsl.Plugin
        ],
        "Built-in Plugs": [
          LocationSimulator.Plug.SyntheticGps,
          LocationSimulator.Plug.GpxReplay,
          LocationSimulator.Plug.Callback,
          LocationSimulator.Plug.Sleep
        ],
        "Worker & Supervisor": [
          LocationSimulator.Worker,
          LocationSimulator.DynamicSupervisor,
          LocationSimulator.Application
        ],
        "GPS & GPX": [
          LocationSimulator.Gps,
          LocationSimulator.Gpx,
          LocationSimulator.Gpx.GpsPoint
        ],
        Callbacks: [
          LocationSimulator.Event,
          LocationSimulator.LoggerEvent
        ]
      ]
    ]
  end

  defp aliases do
    [
      test: ["test --exclude integration"],
      "test.unit": ["test --exclude integration"],
      "test.all": ["test"],
      quality: ["format --check-formatted", "dialyzer"],
      cover: ["test --cover"]
    ]
  end
end
