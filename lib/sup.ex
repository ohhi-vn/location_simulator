defmodule LocationSimulator.DynamicSupervisor do
  @moduledoc """
  DynamicSupervisor, uses for add worker in runtime.

  Module uses PartitionSupervisor for starting workers faster.
  """

  use DynamicSupervisor
  require Logger

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  @spec init(any) ::
          {:ok,
           %{
             extra_arguments: list,
             intensity: non_neg_integer,
             max_children: :infinity | non_neg_integer,
             period: pos_integer,
             strategy: :one_for_one
           }}
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_simulator(maybe_improper_list) :: :ok
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
