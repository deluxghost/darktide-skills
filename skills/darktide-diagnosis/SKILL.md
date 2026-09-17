---
name: darktide-diagnosis
description: "Diagnose Warhammer 40,000: Darktide game and mod problems from logs, runtime observations, and source code. Use for errors, crashes, hangs, disconnects, incorrect behavior, or performance problems, including reports from other users and sessions that have already ended."
license: MIT
metadata:
  author: deluxghost
  version: "1.0.1"
  repository: https://github.com/deluxghost/darktide-skills
---

# Darktide Diagnosis

Investigate mod errors primarily through the Lua call chain, mod/DMF code, and game Lua source, tracing the inputs and lifecycle state shown in the log. Concrete evidence may reveal a need for engine-internal information; at that point, the cause could still be in the engine itself or in mod-supplied data and calls.

## Evidence Selection

Read the supplied material and use the available context to establish its source; a locally stored file does not establish that the failure occurred on this machine. Until the source is confirmed, do not automatically associate it with the local game, local logs, or prior investigations; any necessary local comparison should verify provenance, not assume the same incident. Continue analyzing the available material, and ask only when unresolved provenance affects the next operation.

- Supplied logs or excerpts take precedence over automatic local collection, including reports from other users.
- For the affected running game, use `dt-cli` for recent/live logs and Lua state queries.
- For a crashed or exited game, use its persisted console log. Restarting creates a different session and cannot recover the previous process's dt-cli history.

## Persisted Logs

Windows PC locations, under the affected account:

| Distribution | Console log directory |
| --- | --- |
| Steam | `%APPDATA%\Fatshark\Darktide\console_logs` |
| Xbox app / PC Game Pass / Microsoft Store | `%APPDATA%\Fatshark\MicrosoftStore\Darktide\console_logs` |

These are not Xbox console paths. `%APPDATA%` refers to the account's roaming application-data directory, not the game installation.

Console files are named `console-*.log`. The filename time is UTC; headers marked `UTC time stamps` also use UTC within the log. `[Session]` identifies the session. File size and modification time help select candidates, but multiple installations of the same distribution may share this directory. Use file metadata to select the target log within the scope of the request, then verify its session and incident interval rather than relying on the filename alone. Read additional logs only when specific evidence requires it. Older console logs may no longer be available due to Darktide's own log cleanup.

The parent profile directory may contain `darktide_launcher.log` for launcher, shader-cache builder, or GPU selection problems, even when no console log was created. Bypassing the launcher can leave this file stale.

The platform-specific profile and launcher-log locations are documented by [Fatshark support](https://support.fatshark.se/hc/en-us/articles/7987833276957--PC-How-to-Resolve-Darktide-Using-the-Incorrect-GPU).

## Live Evidence

Darktide buffers native console-log writes, so the file on disk can lag behind; use `dt-cli` for live collection rather than treating the file tail as current output.

`dt-cli` is an optional external tool, included with neither the game nor this skill. If it is missing, direct the user to install LuaExec from [Darktide CLI on Nexus Mods](https://www.nexusmods.com/warhammer40kdarktide/mods/1016); that download includes the client at `<game>/mods/LuaExec/bin/dt-cli.exe`. LuaExec must be loaded in the running game. Resolve `<game>` from context or ask if unknown. Use the separately available `darktide-dt-cli` skill for invocation and PID selection; without that skill, consult the installed client's `--help`.

The current collector captures the native console-log write path, including engine and Lua/mod output, from capture initialization onward. Its history is bounded; dropped bytes, history overruns, and truncated lines are collection gaps. It cannot read existing log files or previous sessions. For earlier history or unavailable collection, use the matching file's available contents.

Log capture and Lua execution are separate services: log output can remain available while Lua queries do not complete. Neither a successful log connection nor a failed Lua query alone establishes the game's failure mechanism.

## Darktide Log Structure

| Marker | Information |
| --- | --- |
| `[Application] STARTUP`, Crashify properties | Engine startup, build/platform and session context. |
| `[Mod] Loading`, `crashify-property Mod:<name> = true` | Mod loading and modded-session metadata. |
| `<<Script Error>>`, `<<Lua Stack>>` | Lua error location/message and call path. |
| `<<Lua Locals>>`, `<<Lua Self>>`, `<<Lua Upvalues>>` | Arguments/locals, receiver state and closure-held values accompanying the Lua error. |
| `<<Crash>>`, `<<Callstack>>` | Crash details and native stack where emitted. |

### Read The Error Block

Use the incident interval to locate `<<Script Error>>` or `<<Crash>>`, then read the associated stack and value sections together. Native assertions may explain the failure in `<<Crash>>` even when there is no Lua exception. A search limited to `error:` or mod names can miss that explanation.

The Lua error headline may abbreviate a path with `...`; the corresponding frame in `<<Lua Stack>>` can provide the full path and line.

In numbered stacks such as `<<Lua Stack>>` and `<Lua Script.Callstack>`, game-resource frames commonly use `@scripts/...`, while mod files use paths such as `./../mods/<mod>/scripts/mods/<mod>/...`; `dmf` in that path identifies framework code. `./mod_loader` identifies the mod loader. In ordinary `stack traceback:` output, game paths can appear without `@`, and mod paths can appear as `[string "./../mods/..."]`. Use the source path to distinguish game and mod code; these prefixes and wrappers depend on how the source name is formatted.

`=[C]` identifies a native binding frame; its Lua caller supplies the call site and arguments. The `[n]` labels in `<<Lua Locals>>`, `<<Lua Self>>`, and `<<Lua Upvalues>>` refer to the same numbered stack frame, not to the nearest preceding line of text.

For game Lua, stack line numbers refer to the original source used to compile the bytecode; decompilation does not preserve this line mapping, so locate the operation by resource path, function name, and error context. For mod/DMF Lua loaded from source, use the stack line directly in the file version loaded when the error occurred.

Value sections can be truncated by the game's report formatter even when their closing tags are present. A field absent from a truncated value section is not evidence that its runtime value was nil. `#ID[...]` can identify units, levels or resources; a readable resource name may instead appear in the caller's locals. `[Unit (deleted) last known ...]` explicitly describes a deleted engine object, rather than an ordinary live unit reference.

### Identify Phase And Responsibility

Read lifecycle frames as part of the failure context: `on_exit`, `destroy`, and `shutdown_behavior_tree` identify teardown paths, while `server_correction_occurred` and `fixed_update_resimulate_unit` identify correction/resimulation paths. An error reached through these paths is not necessarily a failure of the ordinary gameplay update. Locals such as `is_server`, `is_local_unit`, and `is_resimulating` distinguish execution roles. Timer values such as `t` and `main_t` can use different gameplay/main clocks; they are not the log's UTC timestamp.

Player console logs describe the player's own game process. In gameplay stack locals, `is_server = true` identifies locally hosted gameplay in that process, while `is_local_unit` describes local unit ownership.

DMF `hooks.lua`, `hook_chain` and `hook_safe` frames belong to hook dispatch. Normal hooks wrap earlier hooks and receive the preceding function as their first argument, commonly named `func`; safe hooks run after the normal chain returns. Use the source path, line, arguments and wrapper upvalues to distinguish the failing operation from its wrapper. A game-source frame can receive mod-generated data, and a mod frame can merely forward a call. `[MOD]` hook-installation messages, including `needs to be delayed`, describe installation state rather than a runtime failure by themselves.

### When No Exception Explains The Symptom

Use state, loading, connection and subsystem messages from the same interval rather than requiring a `Script Error`. Darktide tracks game state and active UI views separately: a state name does not establish which screen is visible, and closing views can precede completion of a session transition. When logs omit the decisive state, use `dt-cli` to inspect the corresponding managers or flags identified in source. Keep engine `error:` messages and warnings outside a structured crash block as candidates, not automatic causes or automatically harmless noise.

Gameplay connections and backend HTTP/gRPC services have separate lifecycles; a failure in one does not by itself establish a failure in the other. For execution roles, gameplay synchronization, or backend request lifecycles, use the separately available `darktide-networking` skill.

## Report Interpretation Limits

- `Deadlock detected. Update was not called` is an update-watchdog report. Its reported stack can point to detection rather than the blocking operation.
- Native stacks may contain nearest-symbol labels such as repeated `printf` frames when engine symbols are unavailable. These labels do not establish a formatting-function failure.
