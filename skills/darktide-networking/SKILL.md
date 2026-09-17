---
name: darktide-networking
description: "Understand Warhammer 40,000: Darktide networking for mod development. Use when determining where gameplay code executes, whether a mod can affect official or player-hosted sessions, how players and gameplay synchronization interact, or how mods use client backend services."
license: MIT
metadata:
  author: deluxghost
  version: "1.0.0"
  repository: https://github.com/deluxghost/darktide-skills
---

# Darktide Networking

## The Multiplayer Model

Each Darktide process has its own Lua objects, units, and simulation. The processes do not share a Lua world: they exchange player input, messages, and selected game state. The host has final say over gameplay state; clients process input, render the world, and predict their own player's actions between server updates.

Where the host runs determines what a locally installed mod can change:

| Session | Where gameplay authority runs | How players participate |
| --- | --- | --- |
| Official Mourningstar and missions | Fatshark's dedicated server | All players are clients. Private games also use these servers and currently require at least two players in a premade party. |
| Local Psykhanium, tutorials, and mod-started solo missions | The player's game process | The same process runs authoritative gameplay and the local player. The native single-player session has no way for other players to join. SoloPlay and other solo-launching mods reuse this machinery. |
| [Realms](https://www.nexusmods.com/warhammer40kdarktide/mods/1223) | The hosting player's game process | Realms adds the connection and transport integration for other Realms users to join. The host also plays: this is a listen server, not a dedicated or headless server. |

Fatshark does not distribute its dedicated-server program or full server source for public mod development. Mods run in players' game processes, not on official dedicated servers. Host-side mod logic therefore runs through local hosting, including Realms.

Account data, matchmaking, and persistent progression belong to backend services, separately from this gameplay host. Mods access these services through the game's existing Lua interfaces. See [Client backend services](references/backend-services.md) for request handling and frequency.

## From Player Input To Shared Gameplay

For a human playing on a client, the relationship is:

```text
Controlling client -- player input --> Authoritative server
       |                                     |
       | predicts its own player             | simulates accepted gameplay
       |                                     |
       +<-- authoritative state -------------+
       |                                     |
       | corrects prediction                 +-- state/events --> Other clients
       |                                                          represent that player
```

Prediction lets the local player respond before a server round trip completes. Other clients represent that player from received state instead of running that player's local input path. The server, the controlling client, and observing clients can therefore use different implementations for the same player.

A local host combines authority and local-player execution in one process. A mod that changes authoritative gameplay there has not demonstrated that it can change the corresponding behavior as a client on an official server. DMF hooks affect only the process that loaded them.

Client-distributed Lua contains shared code and server-side paths used by local hosting, but not the complete dedicated-server implementation. An `is_server` branch describes an execution role, not a mod capability available everywhere the file exists. Conversely, client execution is not limited to drawing: input and prediction run there too.

## Applying The Model

A mod's effect depends on where its code executes and which existing synchronization carries the result. Host-side changes to already replicated state can reach unmodified clients. New receiving behavior, lookup definitions, or resources need corresponding support at the receiving end.

The following references develop this model:

- [Players and execution roles](references/players-and-roles.md): how peers own players, how those players acquire units, and why authority, local ownership, and human control select different code paths.
- [Connections, messages, and state](references/messages-and-state.md): how a connected peer joins gameplay, how RPCs reach Lua handlers, and how replicated state and late joining differ from individual messages.

Read the relevant part when interpreting those relationships in code. Each reference includes a small set of source entry points; paths are relative to the extracted game resource root.
