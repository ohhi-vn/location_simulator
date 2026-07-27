defmodule LocationSimulator.Plug do
  @moduledoc """
  A plug transforms a pipeline. Inspired by `Plug` from Phoenix.

  Implement `init/1` to validate/transform options at compile/start time.
  Implement `call/2` to transform the pipeline per event.

  ## Example

      defmodule MyApp.SanitizePlug do
        @behaviour LocationSimulator.Plug

        @impl true
        def init(opts), do: opts

        @impl true
        def call(pipeline, _opts) do
          Map.update!(pipeline, :config, &Map.drop(&1, [:secret_key]))
        end
      end
  """

  @doc """
  Called once when the pipeline is assembled.

  Receives the options passed to `plug Module, opts` in the pipeline
  definition. Returns (possibly transformed) opts that will be passed
  to `call/2` on every event.
  """
  @callback init(opts :: term()) :: term()

  @doc """
  Called for each GPS event in the worker loop.

  Receives the pipeline map (with keys `:config`, `:state`, `:gps`,
  `:halted`, `:assigns`) and the compiled opts from `init/1`.

  Return an updated pipeline. Set `halted: true` to stop further
  plug processing for this event (and signal the worker to stop).
  """
  @callback call(pipeline :: map(), opts :: term()) :: map()
end
