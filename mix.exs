defmodule LocationSimulator.MixProject do
  Code.compiler_options(on_undefined_variable: :warn)

  use Mix.Project

  def project do
    [
      app: :location_simulator,
      version: "0.6.3",
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "LocationSimulator",
      source_url: "https://github.com/ohhi-vn/location_simulator",
      homepage_url: "https://ohhi.vn",
      docs: [
        main: "LocationSimulator",
        extras: ["README.md"]
      ],
      description: description(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {LocationSimulator.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:random, "~> 0.2"},
      {:sweet_xml, "~> 0.7"},

      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "A library for generating fake GPS data or load from GPX file/string using for dev/test. The library can generate a GPS series for simulating a sport game and support scalable for test workload."
  end

  defp package() do
    [
      maintainers: ["Manh Vu"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/ohhi-vn/location_simulator", "About us" => "https://ohhi.vn"}
    ]
  end
end

#test new repo
