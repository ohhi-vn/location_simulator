# GenerateGpx

## Introduce

This is an example for using LocationSimulator.

Generate GPX file from LocationSimulator.

## Guide

Just go app folder and run command:

```bash
mix deps.get
mix deps.compile
```

Go to Elixir shell in app:

```bash
iex -S mix
```

Make GPX file:

```elixir
GenerateGpx.gen_gpx("my_gps.gpx", 1000)
```
