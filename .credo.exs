# Used by "mix credo" and CI.
#
# Defaults apply everywhere except where noted: inline nested modules are
# idiomatic in ExUnit tests, so AliasUsage is relaxed there.
%{
  configs: [
    %{
      name: "default",
      strict: true,
      checks: [
        {Credo.Check.Design.AliasUsage, files: %{excluded: ["test/**/*_test.exs"]}}
      ]
    }
  ]
}
