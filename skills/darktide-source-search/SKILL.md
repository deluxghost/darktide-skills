---
name: darktide-source-search
description: "Acquire and query Warhammer 40,000: Darktide Lua source. Use to obtain readable game scripts or locate APIs, classes, modules, UI/HUD code, weapon and talent settings, and gameplay logic for mod development or investigation."
license: MIT
metadata:
  author: deluxghost
  version: "1.0.1"
  repository: https://github.com/deluxghost/darktide-skills
---

# Darktide Lua Source Search

## Select The Source

Prefer these routes in order, unless the user specifies a source:

1. Reuse source identified in the context or project. Check that it contains readable Lua, not just extracted bytecode.
2. Extract and decompile Lua from the relevant game installation.
3. Clone a public source repository when local extraction is unavailable or unsuitable.

For routes 2 and 3, read [Source Acquisition](references/acquisition.md) for tools, workspace paths, cleanup, and optional Git snapshots of locally decompiled source. Resolve the active workspace and existing locations from context; ask only for information needed by the chosen route.

Identify the game source by the following resource layout; `<source>` is the common resource root:

```text
<source>/
|-- content/
|-- core/
|-- dialogues/
`-- scripts/
    `-- main.lua
```

This root may be the repository root or a generated output directory. For build-sensitive questions, establish which game version the source represents; a recent clone or generation timestamp alone does not establish a match.

Client-distributed Lua includes shared logic and server-side paths used by local hosting, but is not the complete dedicated-server source. A function's presence in this tree does not establish that it executes on an official-session client.

## Source Map

Routine queries primarily use `<source>/scripts/`; `content/`, `core/`, and `dialogues/` are rarely needed.

The map below selects directories for common source queries; it is not a complete directory listing. Paths start at `<source>/scripts/`, and indented paths are relative to their parent entry.

- `settings/`: Configuration, balance values, templates, and template callbacks.

  - `equipment/`: Equipment definitions, weapon-handling templates, and trait settings.
  - `damage/`: Damage, armor, impact, and explosion settings and templates.
  - `buff/`: Stat modifiers, trigger conditions, and effect callbacks.
  - `talent/`, `ability/`: Talent parameters, archetype talent definitions, and ability configuration.
  - `breed/`: Unit-type definitions and behavior parameters.
  - `mission/`, `circumstance/`, `mutator/`: Mission definitions, mission variants, and rule modifiers.
  - `ui/`: Shared UI, HUD, and workspace settings.

- `extension_systems/`: Gameplay systems and unit extension classes, grouped by system.
- `managers/`: Subsystem managers and shared services, grouped by subsystem.
- `multiplayer/`: Connection and game-session state machines, joining, and session boot.
- `ui/`: Views, HUD, reusable interface elements, and layout and drawing definitions.

  - `views/`: Individual views and their definitions, settings, and blueprints.
  - `hud/`: HUD element implementations and element-set configuration.
  - `view_elements/`: Reusable view components.
  - `pass_templates/`, `view_content_blueprints/`: Widget drawing-pass templates and reusable content blueprints.
  - `widget_logic/`: Grid layout and scrolling logic.

- `backend/`: Backend service interfaces, data retrieval, and caches.
- `game_states/`: Boot, menu, and gameplay states and their transitions.
- `loading/`: Loading state machines, resource synchronization, and level and unit spawning.
- `utilities/`: Shared gameplay calculations and helper functions.
- `foundation/`: Basic Lua infrastructure, including class support, foundational managers, and environment patches.

## Query Conventions

- **Resource paths:** `require("scripts/...")` and `-- chunkname: @scripts/...` refer to resource-relative paths. Resolve them beneath `<source>`, adding `.lua` for a module path rather than a local repository prefix.
- **Display names and identifiers:** A displayed name may resolve through a localization key shared by several internal templates or variants. Lua often stores the key, while the translated text lives in separately extracted localization data. Match the internal identifier and its references rather than treating one display-name match as unique.
- **Classes and methods:** `class(name, super_name)` registers tables in `CLASSES`; see `scripts/foundation/utilities/class.lua`. Class tables are often local variables, and methods commonly use `Type.method = function (self, ...)`. Missing methods may be inherited from the named superclass.
- **Instances and execution roles:** `Managers.<name>` is an instance reference; trace its assignment to the Lua class. The system key passed to `ScriptUnit.extension(unit, "<system-key>")` is not an extension class name. Unit templates in `scripts/extension_systems/unit_templates` and system registration determine the selected implementation. Server authority, local/remote ownership, and human/bot control are separate dimensions; follow their initialization and caller branches to identify the active implementation.
- **Assembled templates:** Loaders can construct require paths and add fields after loading. For example, `scripts/settings/equipment/weapon_templates/weapon_templates.lua` assembles individual templates. Follow the loader and consumer when a leaf table does not explain the effective value.
- **Source boundaries:** For native APIs such as `Unit`, `World`, and `PhysicsWorld`, Lua callers reveal usage rather than the implementation. DMF APIs and hook dispatch live in the framework's mod source, not the game script tree.

For the network meaning of execution roles, gameplay synchronization, or client backend calls, use the separately available `darktide-networking` skill.

Lua stack-trace line numbers can differ from line numbers in decompiled files. Locate the code using the resource path, function name, and failing expression together.

## Runtime Data

Some data is supplied by backend services or assembled at runtime rather than defined in static Lua. `MasterItems` in `scripts/backend/master_items.lua` is an important example: `MasterItems.get_cached()` reads the backend item cache. Source explains how records are obtained and which fields consumers use, but does not necessarily contain the current records. When those values are needed, use `dt-cli` to inspect the relevant running game's initialized cache; for example, `MasterItems.get_cached()[item_id]` selects a master-item record by its internal ID. `MasterItems.has_data()` reports whether the item cache has data once the backend is available.

`dt-cli` is an optional external tool, included with neither the game nor this skill. If it is missing, direct the user to install LuaExec from [Darktide CLI on Nexus Mods](https://www.nexusmods.com/warhammer40kdarktide/mods/1016); that download includes the client at `<game>/mods/LuaExec/bin/dt-cli.exe`. LuaExec must be loaded in the running game. Resolve `<game>` from context or ask if unknown. Use the separately available `darktide-dt-cli` skill for invocation and PID selection; without that skill, consult the installed client's `--help`.
