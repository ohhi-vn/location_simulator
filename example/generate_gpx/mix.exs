defmodule GenerateGpx.MixProject do
  use Mix.Project

  def project do
    [
      app: :generate_gpx,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:location_simulator, ">= 0.2.0"}
    ]
  end
end
