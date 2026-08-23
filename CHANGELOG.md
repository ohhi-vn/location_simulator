# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0]

### Fixed

- `started_gps` test now actually asserts the first emitted point is near the
  configured start position (it previously started two simulations and asserted
  nothing).
- GPX glob expansion and per-worker file selection now happen in one place
  (`LocationSimulator.Gpx` / `Worker`). Pipeline-based runs distribute multiple
  matched files across workers (round-robin by worker id) exactly like the
  legacy `gpx_file` config path, instead of replaying the first file in every
  worker.
- The GPX replay cursor (`:gpx_data`) moved from `config` into worker `state`,
  so user callbacks no longer receive the whole remaining track on every event.
- Removed dead timing logic from `Plug.GpxReplay`: it computed an
  `assigns.sleep_ms` value that nothing consumed. Sleep/timing is owned by the
  worker loop.
- Documentation drift: `timestamp` in GPS events is wall-clock time
  (`:os.system_time(:millisecond)`), not "ms since worker start";
  `%Gpx.GpsPoint{}.time` is `NaiveDateTime.t() | nil` (was typed as `DateTime`);
  removed the never-incremented `:error` counter from docs, state, logs, and
  `LoggerEvent`.
- `LocationSimulator.default_config/0` reads application env at runtime instead
  of compile time, so consumer configuration set after compilation (e.g. in
  `runtime.exs`) is honored.

### Changed

- `DynamicSupervisor.start_simulator/1` returns `{:error, reason}` for the first
  failing child instead of silently discarding failures; `LocationSimulator.start/*`
  propagates that result (`:ok | {:error, term()}`).
- Invalid GPX globs fail fast at `start` time with a descriptive error
  (`No GPX files matched: ...`) via `Gpx.resolve_files!/1`.
- GPX parsing uses SweetXml's soft-float modifier; missing or invalid `<ele>`
  values become `0.0` without `try/catch`.
- Synthetic GPS positions are floats (matching documented types), and the random
  direction is resolved once per worker and then fixed — now documented
  explicitly.
- Removed redundant per-worker `:rand.seed/2`; the PRNG is seeded automatically.
- Renamed modules' files to match their names:
  `sup.ex` → `location_simulator/dynamic_supervisor.ex`,
  `logger_callback.ex` → `location_simulator/logger_event.ex`.

### Added

- Credo (strict) and Dialyzer to the quality toolchain (`mix quality`),
  with both passing.
- GitHub Actions CI running format check, Credo strict, tests with coverage
  (threshold 90%), and Dialyzer across supported Elixir/OTP versions.
- `CHANGELOG.md` (this file).

## [1.0.0] - 2025

Initial release:

- Spark DSL (`use LocationSimulator.Pipeline`) declaring `source :synthetic | :gpx`
  and ordered `plug` entries at compile time.
- Built-in plugs: `SyntheticGps`, `GpxReplay`, `Callback`, `Sleep`.
- Callback behaviour (`LocationSimulator.Event`) with `start/2`, `event/2`, `stop/2`
  lifecycle and default `LoggerEvent` implementation.
- Legacy flat-config API (`LocationSimulator.start/1`, `start/0`) kept working
  alongside pipeline modules.
- Partitioned DynamicSupervisor + Registry for many concurrent workers and
  group-wise stop via `LocationSimulator.stop/1`.
