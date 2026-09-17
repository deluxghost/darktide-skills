---
name: darktide-modding
description: "Develop and manage Warhammer 40,000: Darktide mods using DML and DMF. Use for developer-side mod installation and load order, framework integration, hook behavior, mod lifecycle, and in-game reloads."
license: MIT
metadata:
  author: deluxghost
  version: "1.0.2"
  repository: https://github.com/deluxghost/darktide-skills
---

# Darktide Modding

## Modding Policy

Develop and use mods within [Fatshark's modding policy](https://forums.fatsharkgames.com/t/darktide-modding-policy/75407). It covers effects on other players, service stability and performance, and bypassing progression or paid content. Access to game internals or authenticated APIs does not exempt a mod from those limits.

## DML And DMF

[Darktide Mod Loader (DML)](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Loader) connects game startup to loose Lua mod files. [Darktide Mod Framework (DMF)](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework) is itself loaded as a mod and supplies the mod object, hooks, events, settings, localization, and developer facilities. Mod code runs inside the game's Lua environment and shares its objects; DMF coordinates extensions to that environment, rather than providing a separate application runtime.

Mods change the process where they are loaded. In official multiplayer that process is a client; in local solo play or on a Realms host it also runs authoritative gameplay. Local server-side changes therefore do not establish that the same feature works on official servers. For gameplay authority, player roles, synchronization, or client backend operations, use the separately available `darktide-networking` skill.

The standard DML startup chain is:

```text
bundle/bundle_database.data
  -> bundle/9ba626afa44a3aa3.patch_999: replacement scripts/main.lua bootstrap
  -> binaries/mod_loader
  -> mods/base/mod_manager.lua
  -> mods/dmf/dmf.mod
  -> mods listed in mods/mod_load_order.txt
```

The replacement bootstrap reads `./mod_loader` through `io.open` and executes it with `loadstring`. The extensionless `binaries/mod_loader` contains an adapted game `main.lua` with loader initialization. It preserves early Lua facilities and connects the base manager to game updates and state changes. This expects `binaries` as the game's working directory, with mods at `../mods`.

DML's [dtkit-patch](https://github.com/manshanko/dtkit-patch) registers the supplied patch bundle in `bundle_database.data`; it does not modify `Darktide.exe`. With the game closed, `dtkit-patch --patch '<game>/bundle'` applies that registration and `--unpatch` restores `bundle_database.data.bak`. The shipped `toggle_darktide_mods.bat` toggles this state, not checks it. Game updates can replace the database and require repatching; updating an individual mod does not. A backup from another game build must not be restored.

## Installed Mods And Load Order

Resolve `<game>` from the request or context; ask if unknown. DML is distributed at [Nexus Mods / 19](https://www.nexusmods.com/warhammer40kdarktide/mods/19), DMF separately at [Nexus Mods / 8](https://www.nexusmods.com/warhammer40kdarktide/mods/8).

- An installed mod has `<game>/mods/<mod-id>/<mod-id>.mod` and the files its descriptor references. The mod directory may be a deployment link rather than the development checkout itself.
- Add the folder ID once to `mods/mod_load_order.txt`. Entries run top to bottom; blank lines and lines beginning with `--` are ignored, surrounding whitespace is trimmed, and inline comments are not supported. Follow documented load-order requirements.
- DML automatically inserts `dmf` first. Neither `dmf` nor `base` belongs in the user entries. DML does not discover every folder or sort mods using `info.json`.
- Removing or commenting an entry excludes the mod on the next reload or launch. Disabling it in DMF leaves it loaded. Preserve load order when updating the loader; a separate mod manager's deployment can overwrite manual changes.
- Replacing mod files does not reset settings: DMF stores them in the game's user configuration, outside the mod folder.

To inspect an installation, compare its mod directories and descriptors with `mod_load_order.txt`: identify missing files, unlisted mods, duplicate entries, and dependency order. For a running game, `get_mod("<registered-name>")` locates a registered DMF object, and `mod:is_enabled()` reads its enabled state. Registration precedes resource initialization, so an object can remain after initialization fails. Combine those queries with the session's loading errors to distinguish installed, selected, successfully initialized, and enabled mods.

## Developing Through DMF

The `.mod` descriptor's startup function calls `new_mod` to register a unique name and its resources. Mod scripts obtain that object with `get_mod`; the name is the registration name, not a display label. DMF itself is `get_mod("DMF")`, although its folder is `dmf`.

The usual `scripts/mods/<mod-id>/` files divide responsibilities: `<mod-id>.lua` holds behavior, `<mod-id>_data.lua` declares mod options and settings, and `<mod-id>_localization.lua` supplies translated strings. The descriptor connects these resources; `info.json` supplies distribution metadata, not runtime registration.

Load bundled game Lua modules with `require("scripts/...")`. Load loose mod files with `mod:io_dofile("<mod-id>/scripts/mods/<mod-id>/<file>")`: the path is relative to the game's `mods` directory, includes the mod folder, and omits `.lua`. Despite their similar `scripts` paths, these use different loaders. `io_dofile` executes the file on each call and returns its results; retain a returned module when it should be initialized only once.

Use the mod object's DMF facilities for hooks, settings, commands, localization, and events. This lets the framework associate registrations with the owning mod and manage them during toggling or reload. Implement game-specific behavior against the actual game objects; editing DML or DMF is not part of installing a mod feature.

For new work, use supported, non-deprecated DMF features. Existing mods may rely on interfaces retained for older code. The [DMF documentation](https://dmf-docs.darkti.de/) and its [Wiki](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/wiki) provide API details and feature-specific deprecation notices.

## Lua Library Access

Obtain Lua/LuaJIT libraries preserved by DML from `Mods.lua`, binding only those the mod needs:

```lua
local io = Mods.lua.io
local os = Mods.lua.os
local ffi = Mods.lua.ffi
```

The [DML bootstrap](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Loader/blob/master/binaries/mod_loader) saves these references before game startup removes or restricts their usual entry points. Use `Mods.lua.debug` and `Mods.lua.loadstring` when those facilities are needed. After binding, use the normal Lua/LuaJIT APIs.

- Relative file paths used with `io` are based on the game's working directory, normally `binaries`, not the mod directory. In contrast, `mod:io_dofile` paths start at the game's `mods` directory.
- FFI declarations share the game's Lua VM across mods and survive mod reloads. Prefix private C types with the mod name and account for repeated declaration during reload; a local `ffi` binding does not isolate declarations.

## Initialization And Enablement

DMF loads a mod's localization, data, and main script in that order, then applies the saved enabled state for toggleable mods. During main-script execution, `mod:is_enabled()` still returns its initial `true`, even for a mod saved as disabled. After the complete mod set has loaded, DMF calls `on_all_mods_loaded`, including for disabled mods.

- Mod data's `is_togglable = true` permits enable/disable switching through DMF. With `is_togglable = false`, the mod remains enabled and does not receive `on_enabled` or `on_disabled`; initialize it in the script or `on_all_mods_loaded`. To exclude it from a test, remove or comment its load-order entry.
- Use `on_all_mods_loaded` for initialization that needs other mods to exist. This event does not imply a player, mission, or UI exists.
- For toggleable mods, use `on_enabled` and `on_disabled` for toggle-dependent behavior. They can run during initial loading as well as later toggles; initial enablement occurs before `on_all_mods_loaded`.
- DMF disables ordinary managed function hooks when a mod is disabled. Event callbacks such as `update` and `on_game_state_changed` are still dispatched; behavior in those callbacks that should stop while disabled needs an enabled-state check.
- Direct changes to game tables are outside hook toggling. Undo them explicitly when disabling or unloading if their lifetime belongs to the mod.

## Configuration And Saved State

The [Windows configuration locations](https://support.fatshark.se/hc/en-us/articles/360017633918--PC-How-to-Provide-a-Crash-Report-Console-Log-Launcher-Log-or-user-settings-config) are:

- Steam: `%APPDATA%\Fatshark\Darktide\user_settings.config`.
- Xbox app / PC Game Pass / Microsoft Store: `%APPDATA%\Fatshark\MicrosoftStore\Darktide\user_settings.config`.

These belong to the Windows user and distribution, not each game installation. Separate installations of the same distribution can share settings. The file uses Fatshark's SJSON syntax, not JSON or Lua. Mod values are under `mods_settings.<registered-name>`; DMF's toggle state is under `mods_settings.DMF.disabled_mods_list`.

- `mod:set` changes DMF's in-memory settings. Saves occur at lifecycle points such as game-state changes and mod unloading; `get_mod("DMF").save_unsaved_settings_to_file()` explicitly flushes pending changes. Edit the file with the game closed, since a running instance can overwrite disk edits.
- `mod:set(id, value, true)` also invokes `on_setting_changed`; omitting the third argument does not. Use notification when a live change must update the mod's derived state, not just its stored value.
- `mod:get` returns a copy of table values. Editing that copy does not save it; write it back with `mod:set`. Saved tables must be serializable arrays or maps, not mixed array/map tables or runtime objects.
- A setting's `default_value` initializes a missing key; changing the default does not replace an existing value. Removing a setting's UI definition does not delete its saved key.
- `mod:persistent_table` keeps a namespaced table across mod reloads in the same process, not across game restarts. It is separate from saved settings.

## Hooks

DMF replaces the target table's function entry with a dispatcher. Regular hooks form a chain around its base implementation; safe hooks run afterward. Register hooks through DMF so multiple mods and enable/disable handling share that dispatcher.

- `mod:hook` wraps the preceding chain. Its supplied `func` is not necessarily the vanilla function: calling it preserves earlier hooks. Later registrations are outer wrappers. Forward the required arguments and return values; calling the hooked table method from inside the hook can recurse.
- `mod:hook_safe` observes a completed call without replacing its return values. It receives the original call arguments, not `func` or the return values. It runs only after the regular chain returns, so it is not an exception handler for that chain.
- `mod:hook_origin` replaces the base implementation while leaving regular wrappers in place. Only one origin replacement can own a target. Use it for an intentional full replacement; a regular hook that omits `func` also cuts off earlier wrappers, and changing load order does not resolve competing replacements.

### Targets And Deferred Hooks

The first argument to `mod:hook`, `mod:hook_safe`, and `mod:hook_origin` identifies the table that owns the method:

- A table obtained from `require("scripts/...")`: hooks that specific returned table, or a nested table selected from it. The method must already exist. The `require` runs before hook registration and can load the module earlier than the game would.
- `CLASS.TargetClass`: uses [DML's class lookup](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Loader/blob/master/mods/base/function/class.lua). A registered class yields its table; an unregistered name yields the string `"TargetClass"`, allowing DMF to defer installation. Use this for a class target without forcing its module to load.
- `"TargetClass"`: DMF looks up that literal name in `_G`, then in `CLASS`. If resolved, it hooks immediately; otherwise it queues the hook. This is a lookup key, not a module path or a dotted Lua expression.

A deferred hook waits to be installed while its named target is unavailable; it does not delay calls after installation. DMF retries on game-state changes and, for classes registered while a hook is pending, before their first construction. Once the target resolves, the method must exist: a missing method on an existing table is not deferred.

For modules returned by `require`, `mod:hook_require` applies to already recorded and future module instances, avoiding a forced early load just to obtain a target. Its callbacks can encounter distinct tables or the same table repeatedly: install a given function hook once per actual target, not once per callback or once globally. This avoids duplicate registration without skipping new instances. The require callback itself is not disabled with the mod, and direct table mutations inside it are not reversible function hooks.

## Localization

Choose the localization route by what consumes the string:

- For mod-owned text, keep translations in the mod's localization file. DMF option widgets localize their titles and tooltips automatically by default: supply mod-local keys, or resolved text only when `localize = false`. For code that accepts display text, resolve the key through `mod:localize`. Do not pass resolved text to an API that will treat it as a localization key again.
- If the game already provides the intended wording, reuse its localization key and resolve it through the game when text is needed. Mod-local keys are not automatically available to the game's `Localize`.
- When a game API expects a key and calls `Localize` internally, register the needed translations through `mod:add_global_localize_strings` and pass that key. Give new global keys a mod-specific prefix and register only the entries that need game-side lookup, not the entire mod localization table. Replacing an existing game key affects its other consumers too; reserve that for intentional changes to the original text.

The [localization documentation](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/wiki/localization) covers mod translation tables and formatting; the [DMF localization implementation](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/blob/master/dmf/scripts/mods/dmf/modules/core/localization.lua) also exposes global registration.

## Resource Packages

Use the `.mod` descriptor's `packages` array for dependencies needed from mod initialization until unloading; use manual loading when package choice or lifetime depends on runtime state. These routes can coexist and are not replacements for one another; see [Loading packages](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/wiki/useful-snippets#loading-packages) for the mechanics.

## Logging

Use the mod's logging methods so DMF identifies the source and controls output routing. Use `mod:debug` for detailed diagnostics, `mod:info` for useful operational information, and `mod:warning` or `mod:error` for actual problems. Reserve `mod:echo` and `mod:notify` for intentional player-facing messages, not routine tracing; avoid per-frame or repeated hook-call logs outside a focused investigation.

DMF log methods use printf-style formatting, not Lua `print` argument joining. Pass already formatted or external text as `mod:info("%s", text)` so literal percent signs remain data. Output routing is configurable, and debug output is disabled by default.

## Reloading During Development

Enable **Developer Mode** in the DMF options and use its **Reload Mods** keybind (default `Ctrl+Shift+R`, configurable). For live Lua access, the DMF entrypoint `get_mod("DMF").request_mod_reload()` requests the same operation; it does nothing unless Developer Mode is enabled.

This reloads the entire mod set, rereads `mod_load_order.txt`, and recreates DMF and mod objects. It does not restart the game or recreate its current player, mission, and UI state. Re-executing one main script is not equivalent and can duplicate registrations.

DMF invokes `on_unload(false)` before a reload and restores its hooked functions; `on_unload(true)` denotes game exit. Release mod-owned resources and reverse unmanaged changes in that lifecycle. Persistent tables and game-side mutations can survive a reload, so process-start initialization and a genuinely clean game state require a restart.

The reload request is queued for a subsequent update. `Managers.mod:all_mods_loaded()` can therefore still be true immediately after the request, while `Mods reloaded.` is emitted before rescanning finishes. Completion means the new loading pass has finished; initialization errors still need to be checked separately.

## Optional Testing Suggestions

During development or before release, consider the following checks where relevant to the mod and the user's request:

- **Minimal mod set:** Launch a fresh game process with only the target mod and its required dependencies selected in `mod_load_order.txt`, then use its features. This can reveal missing module or resource loading masked by other mods.
- **Load order:** Try the target mod near the start and end of the load order, and before and after dependencies and mods affecting the same functionality. Exercise the affected mods to find order-sensitive behavior and determine which ordering requirements need documenting.
- **Enable and disable:** For toggleable mods, disable and re-enable in game, exercising the features in each state to confirm that their effects stop and resume as intended.
- **DMF reload:** Reload through DMF, wait for completion, then exercise the mod again in the current game state. Check functionality as well as loading errors.
- **Play environment:** Test in the environments the mod is intended to support. Local solo play, Realms, and official online sessions use different execution paths; results in one do not substitute for testing another.
