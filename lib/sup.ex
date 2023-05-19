defmodule LocationSimulator.DynamicSupervisor do
  @moduledoc """
  DynamicSupervisor, uses for add worker in runtime.

  Module uses PartitionSupervisor for starting workers faster.
  """

  use DynamicSupervisor
  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_simulator(workers) when is_list(workers) do
    Logger.debug("start worker: #{inspect workers}")
    Enum.each(workers, fn spec ->
      DynamicSupervisor.start_child(
        {:via, PartitionSupervisor, {LocationSimulator.DynamicSupervisor, self()}},
        spec
      )
    end)
  end
end
