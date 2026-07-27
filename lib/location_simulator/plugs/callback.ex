defmodule LocationSimulator.Plug.Callback do
  @moduledoc """
  Dispatches GPS events to the user's callback module.

  The callback module is read from `config.callback` and must implement
  `LocationSimulator.Event`.

  ## Behaviour

  * `{:ok, config}` — updates pipeline config and increments success counter
  * `{:error, _}` — increments failed counter, worker continues
  * `{:stop, _}` — sets `halted: true` to stop worker

  The user can pass `callback: MyModule` in options, or rely on the
  default callback module (taken from config).
  """

  @behaviour LocationSimulator.Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(pipeline, _opts) do
    %{config: config, state: state} = pipeline
    mod = Map.get(config, :callback, LocationSimulator.LoggerEvent)

    case mod.event(config, state) do
      {:ok, new_config} ->
        %{pipeline | config: new_config, state: %{state | success: state.success + 1}}

      {:error, _reason} ->
        %{pipeline | state: %{state | failed: state.failed + 1}}

      {:stop, _reason} ->
        %{pipeline | halted: true}
    end
  end
end
