defmodule LocationSimulator.Plug.Sleep do
  @moduledoc """
  Sleeps for `config.interval` milliseconds (plus optional `config.random_range` jitter).

  This is typically the last plug in the pipeline.
  """

  @behaviour LocationSimulator.Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(pipeline, _opts) do
    %{config: config, state: state} = pipeline

    interval = config.interval
    jitter = Map.get(config, :random_range, 0)
    sleep_ms = interval + Enum.random(0..jitter)

    Process.sleep(sleep_ms)

    %{pipeline | state: Map.put(state, :sleep_ms, sleep_ms)}
  end
end
