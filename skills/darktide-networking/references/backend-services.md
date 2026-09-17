# Client Backend Services

## Gameplay And Account State

The gameplay host simulates a mission; backend services maintain account data and coordinate matchmaking and parties. Locally hosted missions still use the signed-in player's backend services, where inventory, currency, and character changes are persistent.

## How A Client Operation Reaches The Service

Mods call the game's existing Lua service interfaces using the game's authenticated backend session. The usual HTTP request path is:

```text
Game feature / data service
  -> Managers.backend.interfaces.<domain>
  -> Managers.backend:title_request(...)
  -> native Backend -> backend HTTP service
```

Domain interfaces assemble requests and convert responses into the data their callers need. `Managers.data_service` adds higher-level operations and, where implemented, caches, shared in-flight requests, and cache invalidation. Use the existing operation that matches the feature to retain these behaviors.

Backend requests return Promises. `BackendManager.update` collects native completions and resolves or rejects them; domain methods may then extract the response body or transform it. `title_request` also provides bounded backoff retries for some failures, including rate limiting (`429`).

Reading a populated cache uses local data; refreshing it can contact the service. Cache ownership, invalidation, and expiry behavior belong to the corresponding interface or data service.

## Social And Party Updates

Immaterium supplies social and party services through a separate gRPC connection. `Managers.grpc` wraps both individual calls and streams; higher-level managers such as `Managers.presence` maintain state and subscriptions. These updates concern service-visible player and party status, while the engine's gameplay `RPC` and replication handle the mission's units and actions.

## Request Frequency

Keep automated account operations within a frequency a player could realistically produce through normal interaction. Assess the frequency of the complete player-facing operation, which may involve several internal requests.

## Source Entry Points

- `scripts/backend/backend_interface.lua` and its sibling modules: available domain interfaces and their request/response contracts.
- `scripts/foundation/managers/backend/backend_manager.lua` and `utilities/backend_utilities.lua` beneath that directory: native request bridging, Promise completion, retries, and expiry handling.
- `scripts/managers/data_service/`: higher-level operations and cache ownership.
- `scripts/managers/grpc/grpc_manager.lua` and `scripts/managers/presence/`: Immaterium calls, streams, and maintained presence state.
