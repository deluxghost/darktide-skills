# Engine Resources

## Resource Identity

A resource is identified by two 64-bit hashes: one of its type name, such as `unit`, and one of its extensionless, `/`-separated path. Both use MurmurHash64A with seed 0. Type names are recovered by hashing known type strings, and resource paths by matching against a dictionary of known names. The same path with different types is a different resource.

## Bundles And Streams

Each bundle file carries its own index of the resources it contains, so the database only needs to know which files make up a bundle. A resource can keep part of its data in an external stream under `<game>/bundle/data/`, as textures and some materials do. A texture's higher mips are typical stream content. These streams belong to the resource and have to be present for it to load.

## The Bundle Database

`bundle_database.data` holds an ordered file list for each bundle, starting with the base file and followed by its patch files, and the members of each package as (type, name) hash pairs. The game reads it once during startup, before any package is requested.

## Patch Resolution

When loading a bundle, the engine walks its registered file list from the last entry to the first. For each resource, the first file in that walk that contains it supplies it. This is why the most recently registered file wins and earlier files fill in the rest. [Autodesk Stingray's patching documentation](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/stingray_help/after_release/patching.html) describes the same per-resource fallback.

The engine takes the file list as registered and treats each filename as a plain path, so the number in a patch filename has no effect on priority. Numbers can have gaps.

## Package Loading

The game loads its boot packages at startup and keeps them until exit. Other packages are loaded on request. Loading is asynchronous, and completion is reported through a callback. Requests for the same package share one load. Each request is released separately, and the package unloads after the last one is released.
