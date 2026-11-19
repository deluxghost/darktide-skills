---
name: darktide-launch-game
description: "Launch Warhammer 40,000: Darktide on Windows, bypassing the Fatshark launcher. Use to start or check the game, or hide and show its window."
license: MIT
compatibility: "Windows with Windows PowerShell 5.1 or PowerShell 7."
metadata:
  author: deluxghost
  version: "1.0.1"
  repository: https://github.com/deluxghost/darktide-skills
---

# Darktide Launcher

Use `scripts/launch-game.ps1` with Windows PowerShell 5.1 or PowerShell 7.

## Locate The Game

The Darktide game directory is the only installation-specific input.

1. Identify the user's Darktide game directory from the request or available context.
2. From that directory, use `<game>/binaries/Darktide.exe` with `<game>/binaries` as the working directory.
3. Verify that `Darktide.exe` exists at the derived path before launching it.
4. If the game directory is not known, ask the user for it. Do not scan entire drives.

`Status`, `Hide`, and `Show` do not need the game directory.

## Commands

From this skill's directory:

```powershell
& .\scripts\launch-game.ps1 Status
& .\scripts\launch-game.ps1 Start -GameRoot '<game>'
& .\scripts\launch-game.ps1 Start -GameRoot '<game>' -Hidden
& .\scripts\launch-game.ps1 Hide
& .\scripts\launch-game.ps1 Show
```

`Start` is the default action. Use `Start -Hidden` for hidden or unattended launches.

`Start` requires `-GameRoot` and identifies running instances by the full executable path. If that installation is already running, it returns its PIDs without changing those processes. Other installations do not block the launch: use a separate `Start -GameRoot` command for each installation. A new launch writes `steam_appid.txt` and uses the bundled launch arguments.

Since 2024, Darktide has used a discovery service to find its backend endpoints. Do not pass the legacy authentication and title URL overrides together: the engine uses the supplied endpoints instead of running discovery, which can cause backend errors if the URLs are stale.

`Start -ValidateOnly -GameRoot '<game>'` checks prerequisites and reports the running process count for that installation without writing files or launching the game.

`Hide` and `Show` change an existing window without launching a process or writing files. A single running process is selected automatically. For multiple processes, pass `-ProcessId` using the target identified from context; otherwise list them with `Status` and ask the user to choose. No running game or an invalid PID is an error. `Show` restores minimized windows.

Window operations wait up to 120 seconds for the main window (`-WindowTimeoutSeconds` overrides this), confirm the requested visibility, and return. The script does not monitor the session or close any surviving game process on error.

## Session Lifecycle

Follow the user's instructions about when to leave the game running or close it. Otherwise, close an instance you started solely to complete the current task once it is no longer needed, even if the task fails. Leave pre-existing instances and instances intended for the user running. If the user has taken over or it is unclear whether they still need the instance, leave it running and say so. Do not infer that a hidden or idle instance is unused. Before closing, verify the process identity, request a normal exit, and confirm that it exited.

## Results

- `NOT_RUNNING` or `RUNNING`: process status; `RUNNING` includes PID and executable path.
- `STARTED`: the process was created, but game loading is not confirmed.
- `HIDDEN` or `SHOWN`: the requested window state was confirmed.
