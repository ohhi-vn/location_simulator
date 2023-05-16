defmodule LocationSimulator.MixProject do
  use Mix.Project

  def project do
    [
      app: :location_simulator,
      version: "0.1.0",
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:nestru, "~> 0.3.2"},
      {:jason, "~> 1.4.0"},
      {:math, "~> 0.7.0"},
      {:random, "~> 0.2.4"},
      {:phoenix_gen_socket_client, "~> 4.0"}
    ]
  end
end

#test new repo
