defmodule LocationSimulator.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    Logger.debug("start LocationSimulator app")

    children = [
      {PartitionSupervisor,
       child_spec: DynamicSupervisor,
       name: LocationSimulator.DynamicSupervisor},
       {Registry, keys: :duplicate, name: LocationSimulator.Registry}
    ]

    Logger.debug("LocationSimulator application load with children: #{inspect children}")

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LocationSimulator.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
