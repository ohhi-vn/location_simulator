defmodule LocationSimulator.Worker do
  @moduledoc """
  Runs a GPS simulation loop using a plug pipeline.

  The worker resolves the pipeline module, builds the per-event plug chain,
  fires lifecycle callbacks, and loops until the event counter is exhausted
  or a stop signal arrives.
  """

  require Logger

  alias LocationSimulator.{Gpx, Gps}

  @spec start_link(map()) :: {:ok, pid()}
  def start_link(arg), do: start_link(__MODULE__, arg)

  @spec start_link(module(), map()) :: {:ok, pid()}
  def start_link(module, arg) do
    pid = spawn_link(module, :init, [arg])
    {:ok, pid}
  end

  @doc false
  @spec child_spec(map()) :: map()
  def child_spec(opts) when is_map(opts) do
    %{
      id: Map.get(opts, :id, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: Map.get(opts, :restart, :temporary),
      shutdown: Map.get(opts, :shutdown, :brutal_kill)
    }
  end

  @doc false
  @spec init(map()) :: :ok
  def init(config) do
    state = init_state()
    config = fire_start!(config, state)
    :rand.seed(:exsss)

    {config, plugs} = build_plugs(config)

    gps = initial_gps(config)
    state = Map.put(state, :gps, gps)

    maybe_register(config)

    counter = Map.get(config, :event, :infinity)
    id = Map.get(config, :id, self())

    Logger.debug("Worker #{inspect(id)}: starting loop, events=#{inspect(counter)}")

    loop(config, state, plugs, counter, id)
  end

  defp loop(config, state, plugs, counter, id) do
    if done?(config, counter) do
      fire_stop!(config, state)
      :ok
    else
      sleep_ms = sleep_duration(config, state)
      Process.sleep(sleep_ms)

      pipeline = %{
        config: config,
        state: state,
        gps: state.gps,
        halted: false,
        assigns: %{}
      }

      pipeline = run_plugs(pipeline, plugs)

      if pipeline.halted do
        Logger.debug("Worker #{inspect(id)}: pipeline halted")
        fire_stop!(pipeline.config, pipeline.state)
        :ok
      else
        receive do
          {:stop_worker, ^id} ->
            Logger.debug("Worker #{inspect(id)}: stop received from group manager")
            fire_stop!(pipeline.config, pipeline.state)
            :ok
        after
          0 ->
            loop(pipeline.config, pipeline.state, plugs, next_counter(counter), id)
        end
      end
    end
  end

  defp done?(_config, 0), do: true
  defp done?(_config, _counter), do: false

  defp build_plugs(config) do
    pipeline_mod = Map.get(config, :pipeline)
    {source, user_plugs} = resolve_pipeline(pipeline_mod, config)

    config = merge_source_into_config(config, source)

    source_gps_plug = source_gps_module(source.type)
    source_opts = source_gps_plug.init(config)

    {config, [{source_gps_plug, source_opts} | user_plugs]}
  end

  defp resolve_pipeline(nil, config) do
    if Map.has_key?(config, :gpx_file) do
      {default_gpx_source(config), default_plugs()}
    else
      {default_synthetic_source(config), default_plugs()}
    end
  end

  defp resolve_pipeline(mod, _config) when is_atom(mod) do
    LocationSimulator.Pipeline.__pipeline__(mod)
  end

  defp default_synthetic_source(config) do
    %LocationSimulator.Dsl.Source{
      type: :synthetic,
      direction: Map.get(config, :direction, :random),
      elevation: Map.get(config, :elevation, 0),
      elevation_way: Map.get(config, :elevation_way, :no_up_down),
      started_gps: Map.get(config, :started_gps)
    }
  end

  defp default_gpx_source(config) do
    %LocationSimulator.Dsl.Source{
      type: :gpx,
      gpx_file: config.gpx_file,
      started_gps: Map.get(config, :started_gps)
    }
  end

  defp default_plugs do
    [{LocationSimulator.Plug.Callback, []}]
  end

  defp merge_source_into_config(config, source) do
    config
    |> Map.put(:direction, source.direction || Map.get(config, :direction, :random))
    |> Map.put(:elevation, source.elevation || Map.get(config, :elevation, 0))
    |> Map.put(:elevation_way, source.elevation_way || Map.get(config, :elevation_way, :no_up_down))
    |> then(fn cfg ->
      if source.started_gps, do: Map.put(cfg, :started_gps, source.started_gps), else: cfg
    end)
    |> then(fn cfg ->
      if source.type == :gpx && source.gpx_file,
        do: load_gpx_data(cfg, source.gpx_file),
        else: cfg
    end)
  end

  defp load_gpx_data(config, glob) do
    files = Path.wildcard(glob)
    if files == [], do: raise("No GPX files matched: #{glob}")

    config
    |> Map.put(:gpx_data, Gpx.read_gpx(hd(files)))
    |> Map.put(:gpx_files, files)
  end

  defp source_gps_module(:synthetic), do: LocationSimulator.Plug.SyntheticGps
  defp source_gps_module(:gpx), do: LocationSimulator.Plug.GpxReplay

  defp run_plugs(pipeline, [{plug_mod, opts} | rest]) do
    pipeline
    |> plug_mod.call(opts)
    |> then(fn p -> if p.halted, do: p, else: run_plugs(p, rest) end)
  end

  defp run_plugs(pipeline, []), do: pipeline

  defp next_counter(:infinity), do: :infinity
  defp next_counter(n) when is_integer(n), do: n - 1

  defp sleep_duration(%{interval: :gpx_time, gpx_data: [next | _]}, %{gps: %{time: prev_time}}) when not is_nil(prev_time) do
    max(NaiveDateTime.diff(next.time, prev_time, :millisecond), 0)
  end

  defp sleep_duration(%{interval: :gpx_time}, _state), do: 0

  defp sleep_duration(%{interval: interval, random_range: range}, _state) do
    interval + Enum.random(0..range)
  end

  defp sleep_duration(%{interval: interval}, _state), do: interval

  defp sleep_duration(_config, _state), do: 100

  defp initial_gps(%{started_gps: {lat, lon, ele}}) do
    %{timestamp: 0, lat: lat, lon: lon, ele: ele}
  end

  defp initial_gps(%{gpx_data: [first | _rest]}) do
    %{timestamp: 0, time: first.time, lat: first.lat, lon: first.lon, ele: first.ele}
  end

  defp initial_gps(config) do
    {lat, lon} = Gps.generate_pos()
    ele = Map.get(config, :elevation, 0)
    %{timestamp: 0, lat: lat, lon: lon, ele: ele}
  end

  defp fire_start!(%{callback: mod} = config, state) do
    id = Map.get(config, :id, self())

    case mod.start(config, state) do
      {:ok, new_config} ->
        new_config

      {:error, reason} ->
        raise "Worker #{inspect(id)}: start callback failed – #{inspect(reason)}"
    end
  end

  defp fire_start!(config, _state), do: config

  defp fire_stop!(%{callback: mod} = config, state) do
    id = Map.get(config, :id, self())

    stop_time = unix_seconds()
    state = Map.put(state, :stop_time, stop_time)

    case mod.stop(config, state) do
      {:ok, _cfg} -> :ok
      {:error, reason} -> raise "Worker #{inspect(id)}: stop callback failed – #{inspect(reason)}"
    end

    elapsed = stop_time - state.start_time

    Logger.debug(
      "Worker #{inspect(id)} DONE – elapsed: #{elapsed}s, " <>
        "success: #{state.success}, failed: #{state.failed}, error: #{state.error}"
    )
  end

  defp fire_stop!(_config, _state), do: :ok

  defp maybe_register(%{group_id: group_id, id: id}) do
    Registry.register(LocationSimulator.Registry, group_id, id)
    :ok
  end

  defp maybe_register(_config), do: :ok

  defp init_state do
    %{start_time: unix_seconds(), success: 0, failed: 0, error: 0}
  end

  defp unix_seconds, do: :os.system_time(:seconds)
end
