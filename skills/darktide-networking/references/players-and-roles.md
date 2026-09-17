# Players And Execution Roles

## One Player, Several Representations

A peer is a participant in the engine's network, identified by a peer ID; a player is a logical gameplay participant owned by a peer. These are not one-to-one: a host can own its human player and bots. The pair `(peer_id, local_player_id)` identifies a player; `local_player_id` is an index within its owning peer.

Each process keeps player records for the participants it knows about. `Managers.player:local_player(id)` selects a player owned by the current peer, whereas the human-player collection also includes remote humans. "Local" answers whose player this is relative to the process; "human" answers what controls it. A remote player can be a human or a bot.

The player's body in the level is a separate object, `player.player_unit`. The player record can exist before that unit is spawned or after it is removed. Each machine creates its own corresponding unit, with its own extensions; network identity connects these representations rather than sharing a `Unit` handle between processes.

## Ownership Does Not Grant Gameplay Authority

The authoritative host simulates gameplay for players owned both locally and by other peers. On a client, its own human player uses input and prediction, while other players use husk implementations that consume remote state. Thus "my player" does not mean "my process decides its authoritative state."

These distinctions appear in code as `is_server`, `is_local_unit`, and `player:is_human_controlled()`. Unit templates combine them when selecting extensions. In the player-character template, even `husk_init` selects between remote husks and the local client's player implementation: its name alone does not identify the active branch.

For an established gameplay session, `Managers.state.game_session:is_server()` identifies authority. A local host can return true without being a dedicated server; `DEDICATED_SERVER` identifies the latter execution environment. Systems and extensions receive their role through initialization, so the template and constructor explain what a particular `is_server` branch means.

## Prediction Runs Some Code More Than Once

The local client's simulation runs ahead of authoritative updates. `PlayerUnitDataExtension` compares saved predicted state with server state. When they disagree, it applies correction and replays fixed simulation frames through the extension system with `is_resimulating` set.

The replay is part of normal simulation, not a second player action. A hook in that path may therefore execute again for the same frame. Other players' husk extensions consume remote state rather than replaying this local-input history.

## Source Entry Points

- `scripts/foundation/managers/player/player_manager.lua`: player ownership and lookup; concrete player classes are in `scripts/managers/player/`.
- `scripts/extension_systems/unit_templates/player_character_unit_template.lua`: how roles select a player's extensions.
- `scripts/extension_systems/unit_data/player_unit_data_extension.lua`: the local player's predicted data and server correction; `player_husk_data_extension.lua` in the same directory handles remote data.
