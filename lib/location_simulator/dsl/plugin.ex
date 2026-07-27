defmodule LocationSimulator.Dsl.Plugin do
  @moduledoc """
  DSL entity representing a plug module in the pipeline.

  Defined at compile time via `plug` inside a `use LocationSimulator.Pipeline` module.
  """
  defstruct [:module, :opts, :__spark_metadata__]
end
