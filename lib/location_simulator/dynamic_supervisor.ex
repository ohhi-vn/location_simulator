defmodule LocationSimulator.DynamicSupervisor do
  @moduledoc """
  DynamicSupervisor, uses for add worker in runtime.

  Module uses PartitionSupervisor to improve performance when start workers.
  """

  use DynamicSupervisor
  require Logger

  @spec start_link(term()) :: :ignore | {:error, any} | {:ok, pid}
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

  @doc """
  Starts all worker specs.

  Returns `{:error, reason}` of the first failing child; already-started
  workers are left running.
  """
  @spec start_simulator([tuple()]) :: :ok | {:error, term()}
  def start_simulator(workers) when is_list(workers) do
    Logger.debug("start workers: #{inspect(workers)}")

    workers
    |> Enum.reduce_while(:ok, fn spec, :ok ->
      case start_child(spec) do
        {:ok, _pid} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp start_child(spec) do
    key = routing_key(spec)

    DynamicSupervisor.start_child(
      {:via, PartitionSupervisor, {__MODULE__, key}},
      spec
    )
  end

  # Workers with the same id are routed to the same partition.
  defp routing_key({_module, %{id: id}}) when id != nil, do: id
  defp routing_key(_spec), do: self()
end
