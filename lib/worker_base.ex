defmodule LocationSimulator.WorkerBase do
  @moduledoc """
  Shared helpers for `Worker` and `WorkerGpx`.

  Provides child spec generation, process linking, registry management,
  timestamp utilities, and the start/stop event lifecycle.
  """

  require Logger

  # ── OTP boilerplate ────────────────────────────────────────────────────────

  @doc "Returns a temporary `DynamicSupervisor`-compatible child spec."
  @spec child_spec(module(), map()) :: map()
  def child_spec(module, opts) when is_map(opts) do
    %{
      id: Map.get(opts, :id, module),
      start: {module, :start_link, [opts]},
      type: :worker,
      restart: Map.get(opts, :restart, :temporary),
      shutdown: Map.get(opts, :shutdown, :brutal_kill)
    }
  end

  @doc "Spawns `module.init/1` linked to the calling process."
  @spec start_link(module(), map()) :: {:ok, pid()}
  def start_link(module, arg) do
    pid = spawn_link(module, :init, [arg])
    {:ok, pid}
  end

  # ── Registry ───────────────────────────────────────────────────────────────

  @doc "Registers the current process under `group_id` when present in config."
  @spec maybe_register(map()) :: :ok
  def maybe_register(%{group_id: group_id, id: id}) do
    Registry.register(LocationSimulator.Registry, group_id, id)
    :ok
  end

  def maybe_register(_config), do: :ok

  # ── Lifecycle events ───────────────────────────────────────────────────────

  @doc """
  Fires `callback.start/2`.

  Returns the (possibly updated) config on success, raises on error.
  """
  @spec fire_start!(map(), map()) :: map()
  def fire_start!(%{callback: mod} = config, state) do
    id = Map.get(config, :id, self())
    Logger.debug("Worker #{inspect(id)}: firing start event")

    case mod.start(config, state) do
      {:ok, new_config} ->
        new_config

      {:error, reason} ->
        raise "Worker #{inspect(id)}: start callback failed – #{inspect(reason)}"
    end
  end

  @doc """
  Fires `callback.stop/2`, logs completion, and returns the updated config.
  """
  @spec fire_stop!(map(), map()) :: map()
  def fire_stop!(%{callback: mod} = config, state) do
    id = Map.get(config, :id, self())
    Logger.debug("Worker #{inspect(id)}: firing stop event")

    stop_time = unix_seconds()
    state = Map.put(state, :stop_time, stop_time)

    new_config =
      case mod.stop(config, state) do
        {:ok, cfg} ->
          cfg

        {:error, reason} ->
          raise "Worker #{inspect(id)}: stop callback failed – #{inspect(reason)}"
      end

    elapsed = stop_time - state.start_time

    Logger.debug(
      "Worker #{inspect(id)} DONE – elapsed: #{elapsed}s, " <>
        "success: #{state.success}, failed: #{state.failed}, error: #{state.error}"
    )

    new_config
  end

  # ── Utilities ──────────────────────────────────────────────────────────────

  @doc "Current Unix time in seconds."
  @spec unix_seconds() :: non_neg_integer()
  def unix_seconds, do: :os.system_time(:seconds)

  @doc "Initial worker statistics map."
  @spec init_state() :: map()
  def init_state do
    %{start_time: unix_seconds(), success: 0, failed: 0, error: 0}
  end
end
