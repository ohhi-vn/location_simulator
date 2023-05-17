# LocationSimulator

Use for simulating location(longitude, latitude) data. Support scalable for test workload.

## Achitecture

The library has 3 main part:
1. Supervisor. Lib uses DynamicSupervisor for creating worker from config.
2. Worker. Generating GPS with user config.
3. Callback module. This is defined by user to handle event from worker.

```mermaid
sequenceDiagram
    participant CallbackMod
    participant Worker
    participant Api
    participant Sup

    Api->>Sup: Start with workers from config
    Sup->>Worker: Start GPS generator
    Worker->>CallbackMod: call start event
    Worker->>CallbackMod: call gps event
    Worker->>CallbackMod: call stop event
```

## Dev Guide


