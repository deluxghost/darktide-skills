# Connections, Messages, And State

## From Transport To A Gameplay Session

Below the Lua managers, the engine's native `Network` layer provides packet transport, channels, and message serialization. Gameplay traffic uses UDP with engine-managed reliability and compression; a game "connection" is not a TCP socket managed by Lua. Above that transport, Lua connection state machines negotiate compatibility, player slots, and player data. An engine channel can already be connected while these steps are still pending.

Connecting to a host and joining its current gameplay are separate lifetimes. `Managers.connection` establishes the peer connection. `Managers.multiplayer_session` coordinates session boot, joining, and leaving; `Managers.state.game_session` wraps the native `GameSession` containing the current gameplay's membership and replicated objects. A connection can remain while that gameplay manager is absent during a transition.

A peer ID identifies the participant; a channel ID is this process's handle for communicating with it. Connection traffic and gameplay-session traffic have separate channel mappings, even for the same peer. Sending helpers on the two managers use their respective mappings. The ordinary gameplay topology connects clients to the host, so knowing another player's peer ID does not establish a direct client-to-client channel.

## RPC Moves An Event Across That Connection

An RPC carries a named message with a defined payload. The sender chooses a destination channel; the engine serializes and transports the message, then dispatches it to Lua at the destination:

```text
RPC.<name>(destination_channel, payload...)
  -> native network transport
  -> NetworkEventDelegate
  -> receiver:<name>(sender_channel, payload...)
```

The receiver sees a sender channel local to its own process. It uses the message and the current game state to decide what happens next. Calling that receiver method directly skips transport and only executes local Lua.

Message names and payloads are defined by the native network configuration. Registering a Lua handler connects an existing message to an object; it does not create a new network message type. RPCs serve several purposes: connection negotiation, gameplay requests, and notifications of results. For a client-to-server gameplay request, the receiving logic decides whether to accept it; delivery alone is not approval.

## Replication Carries State, Not Lua Objects

RPCs convey events and requests. Native `GameSession` objects instead expose declared fields for synchronization. When a networked unit is spawned, receiving peers create corresponding local units and initialize their extensions from that network state. Ordinary Lua tables, local units, and changes to them do not become shared merely because the game is connected.

This also explains why peers need matching definitions. `NetworkLookup` encodes names as numeric IDs; the receiver interprets those IDs through its own tables and loads templates and resources it already has. The message carries the identifier, not the referenced mod code or asset. Units likewise cross the boundary as game-object IDs or level-unit indices, not process-local handles.

A newly joined client needs the current world, not just messages sent from now on. Native game-object synchronization supplies replicated objects; Lua game systems use `hot_join_sync` to send additional current state. Together they establish the client's starting state. A one-time RPC is not saved history for future joiners. Game-session objects also belong to their session, even when the connection survives a level change.

## Mod Messages Use An Additional Protocol

Realms provides a separate mod-message API over its active connections. Participating peers need Realms and matching receiving mod registrations. This supplements the game's native RPCs without adding handlers to official servers. Its [developer documentation](https://github.com/deluxghost/darktide-mods/tree/main/Realms/docs) covers registration, sending, and connection readiness.

## Source Entry Points

- `scripts/managers/multiplayer/`: connection and game-session managers, plus `network_event_delegate.lua` for RPC dispatch. Their state machines live under `scripts/multiplayer/`.
- `scripts/foundation/managers/unit_spawner/unit_spawner_manager.lua`: the relationship between network objects and local units.
- `scripts/network_lookup/network_lookup.lua`: the shared name/ID vocabulary.
