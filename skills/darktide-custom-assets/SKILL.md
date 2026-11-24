---
name: darktide-custom-assets
description: "Create custom Warhammer 40,000: Darktide resources such as models, textures, and animations, and load them into the game from a mod. Use when generating compiled resources, registering them with the game, or loading them at runtime."
license: MIT
metadata:
  author: deluxghost
  version: "1.0.0"
  repository: https://github.com/deluxghost/darktide-skills
---

# Darktide Custom Assets

## How The Game Loads Resources

Everything Darktide loads from its bundles, including models, textures, materials, animations, shaders, and Lua scripts, is a compiled resource in an engine format. Each resource is identified by a type, such as `unit` or `texture`, and an extensionless path, such as `content/characters/...`. The engine works with hashes of both.

Resources are stored in bundle files under `<game>/bundle`, named by hash. Large data, such as high-resolution texture mips, can sit in separate stream files under `<game>/bundle/data/`.

Lua loads resources by package. A package is a list of typed resources, which can come from several bundles. The game loads a few boot packages at startup and requests others at runtime through `Managers.package`.

`<game>/bundle/bundle_database.data` ties these together. It registers which bundles exist, which files make up each bundle, and which resources each package contains. The game reads it at startup, so only packages registered there can be loaded, and changes take effect at the next start.

### Patches

A bundle can be registered with additional patch files, named `<bundle-hash>.patch_<number>`. The engine combines them per resource. For each resource, the most recently registered file that contains it wins, and resources a patch does not contain still come from earlier files. A patch can therefore replace or add a few resources while the rest of the bundle stays in place.

Priority follows registration order in the database, and the number in the filename is only a naming convention. Patches that touch different resources coexist. Some mod tools use patches to get their content loaded. Darktide Mod Loader, for example, uses one to replace the game's Lua bootstrap.

[Engine Resources](references/engine-resources.md) covers these mechanisms in more detail: how resource hashes are computed, what bundles and the database each record, how the engine resolves patches, and how package requests are shared and released.

## Adding Resources From A Mod

A mod that brings its own resources has to provide them in their engine formats, along with anything they reference that the game does not already have, such as a unit's materials and textures. Bundles and a package containing them then have to be registered in the database before the game reads it. From there, the mod loads the package the same way it loads a native one, as described in `darktide-modding`.

A commonly used combination handles producing and registering the resources. Read each tool's current documentation for usage.

[Darktide Asset Compiler](https://github.com/fviuff/Darktide-SDK) builds model-related resources from Blender or glTF, including units, materials, textures, skeletons, animations, physics, particle effects, and lights.

[Custom Assets](https://www.nexusmods.com/warhammer40kdarktide/mods/1200) handles registration at game startup. It collects asset folders from installed mods, writes a bundle and package for each folder, registers them in the database, and adds the new packages to the boot package through a patch. It accepts compiler output and any other folder of compiled resources, and it provides a Lua API for loading them. Its source and documentation are in [Custom-Assets-patcher](https://github.com/fviuff/darktide-mods/tree/main/Custom-Assets-patcher).
