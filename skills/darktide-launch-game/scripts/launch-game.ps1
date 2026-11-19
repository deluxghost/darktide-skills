#Requires -Version 5.1
<#
.SYNOPSIS
Launch or check Darktide, or hide and show its existing window.
.PARAMETER Action
Start (default), Status, Hide, or Show. May be supplied as the first argument.
.PARAMETER Hidden
Start with a hidden window.
.PARAMETER GameRoot
Darktide installation directory. Required for Start, including ValidateOnly.
.PARAMETER ProcessId
Target PID for Hide or Show. Optional when exactly one Darktide process is running.
.PARAMETER WindowTimeoutSeconds
Maximum wait for the main window. Defaults to 120 seconds.
.PARAMETER ValidateOnly
Check Start prerequisites without writing files or launching the game.
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Start', 'Status', 'Hide', 'Show')]
    [string] $Action = 'Start',

    [switch] $Hidden,

    [string] $GameRoot,

    [ValidateRange(1, 2147483647)]
    [int] $ProcessId,

    [ValidateRange(1, 86400)]
    [int] $WindowTimeoutSeconds = 120,

    [switch] $ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'This launcher requires Windows.'
}

$isStart = $Action -eq 'Start'
$isWindowAction = $Action -in @('Hide', 'Show')
if (-not $isStart) {
    foreach ($name in @('GameRoot', 'Hidden', 'ValidateOnly')) {
        if ($PSBoundParameters.ContainsKey($name)) {
            throw "$name applies only to Start."
        }
    }
}
if ($PSBoundParameters.ContainsKey('ProcessId') -and -not $isWindowAction) {
    throw 'ProcessId applies only to Hide and Show.'
}

function Write-RunningProcesses {
    param([Diagnostics.Process[]] $Processes)

    if ($Processes.Count -eq 0) {
        Write-Output 'NOT_RUNNING'
    }
    foreach ($process in $Processes) {
        Write-Output ('RUNNING pid={0} path={1}' -f $process.Id, $process.Path)
    }
}

$running = @(Get-Process -Name 'Darktide' -ErrorAction SilentlyContinue)
if ($Action -eq 'Status') {
    Write-RunningProcesses -Processes $running
    return
}

if ($isStart) {
    if ([string]::IsNullOrWhiteSpace($GameRoot)) {
        throw 'GameRoot is required. Specify the Darktide installation directory.'
    }

    $executablePath = Join-Path (Join-Path $GameRoot 'binaries') 'Darktide.exe'
    if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
        throw "Darktide executable not found: $executablePath"
    }
    $executablePath = (Resolve-Path -LiteralPath $executablePath).ProviderPath
    $running = @($running | Where-Object {
        [string]::Equals($_.Path, $executablePath, [StringComparison]::OrdinalIgnoreCase)
    })
    if ($running.Count -gt 0 -and -not $ValidateOnly) {
        Write-RunningProcesses -Processes $running
        return
    }
}

if ($isWindowAction) {
    if ($PSBoundParameters.ContainsKey('ProcessId')) {
        $running = @($running | Where-Object { $_.Id -eq $ProcessId })
        if ($running.Count -eq 0) {
            throw ("No running Darktide process has PID {0}." -f $ProcessId)
        }
    }
    if ($running.Count -eq 0) {
        throw 'Darktide is not running.'
    }
    if ($running.Count -gt 1) {
        Write-RunningProcesses -Processes $running
        throw 'Multiple Darktide processes are running. Specify ProcessId.'
    }
}

if (($Hidden -or $isWindowAction) -and -not ('DarktideLaunchGame.GameWindow' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace DarktideLaunchGame
{
    public static class GameWindow
    {
        private const int SW_HIDE = 0;
        private const int SW_SHOW = 5;
        private const int SW_RESTORE = 9;
        private const string MainWindowClass = "main_window";
        private delegate bool EnumWindowsProc(IntPtr window, IntPtr parameter);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr parameter);

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetClassNameW(IntPtr window, StringBuilder className, int maximumCount);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool ShowWindowAsync(IntPtr window, int command);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsWindow(IntPtr window);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsWindowVisible(IntPtr window);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsIconic(IntPtr window);

        public static IntPtr FindMainWindow(int processId)
        {
            var found = IntPtr.Zero;
            var enumerated = EnumWindows((window, parameter) =>
            {
                uint ownerProcessId;
                GetWindowThreadProcessId(window, out ownerProcessId);
                if (ownerProcessId != (uint)processId)
                {
                    return true;
                }

                var className = new StringBuilder(256);
                GetClassNameW(window, className, className.Capacity);
                if (className.ToString() != MainWindowClass)
                {
                    return true;
                }

                found = window;
                return false;
            }, IntPtr.Zero);

            if (!enumerated && found == IntPtr.Zero)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not enumerate game windows.");
            }
            return found;
        }

        public static void SetVisible(IntPtr window, bool visible)
        {
            var command = visible ? (IsIconic(window) ? SW_RESTORE : SW_SHOW) : SW_HIDE;
            if (!ShowWindowAsync(window, command))
            {
                throw new InvalidOperationException("Could not request the game window visibility change.");
            }
        }
    }
}
'@
}

function Set-GameWindowVisibility {
    param(
        [Diagnostics.Process] $Process,
        [bool] $Visible
    )

    $pollMilliseconds = 100
    $windowTimer = [Diagnostics.Stopwatch]::StartNew()
    $window = [IntPtr]::Zero
    while ($windowTimer.Elapsed.TotalSeconds -lt $WindowTimeoutSeconds) {
        if ($process.HasExited) {
            throw ('Darktide exited before its main window appeared: pid={0}, exit_code={1}.' -f $process.Id, $process.ExitCode)
        }
        $window = [DarktideLaunchGame.GameWindow]::FindMainWindow($process.Id)
        if ($window -ne [IntPtr]::Zero) {
            break
        }
        Start-Sleep -Milliseconds $pollMilliseconds
    }
    if ($window -eq [IntPtr]::Zero) {
        throw ('Darktide main window did not appear within {0} seconds: pid={1}. The process was left running.' -f $WindowTimeoutSeconds, $process.Id)
    }

    [DarktideLaunchGame.GameWindow]::SetVisible($window, $Visible)
    $operationTimeoutMilliseconds = 5000
    $operationTimer = [Diagnostics.Stopwatch]::StartNew()
    while ($operationTimer.ElapsedMilliseconds -lt $operationTimeoutMilliseconds) {
        if ($process.HasExited -or -not [DarktideLaunchGame.GameWindow]::IsWindow($window)) {
            throw ('Darktide exited or its main window closed before visibility was confirmed: pid={0}.' -f $process.Id)
        }
        if ([DarktideLaunchGame.GameWindow]::IsWindowVisible($window) -eq $Visible -and
            (-not $Visible -or -not [DarktideLaunchGame.GameWindow]::IsIconic($window))) {
            $result = if ($Visible) { 'SHOWN' } else { 'HIDDEN' }
            Write-Output ('{0} pid={1} hwnd=0x{2:X}' -f $result, $process.Id, $window.ToInt64())
            return
        }
        Start-Sleep -Milliseconds $pollMilliseconds
    }
    throw ('Darktide window visibility change could not be confirmed: pid={0}. The process was left running.' -f $process.Id)
}

if ($isStart) {
    $workingDirectory = [IO.Path]::GetDirectoryName($executablePath)
    $steamAppIdPath = Join-Path $workingDirectory 'steam_appid.txt'
    $gameArguments = @(
        '--bundle-dir'
        '../bundle'
        '--ini'
        'settings'
        '--lua-heap-mb-size'
        '2048'
    )

    if ($ValidateOnly) {
        [pscustomobject]@{
            Ok = $true
            ExecutablePath = $executablePath
            WorkingDirectory = $workingDirectory
            Arguments = $gameArguments
            ExistingProcessCount = $running.Count
            Hidden = [bool] $Hidden
        } | ConvertTo-Json -Compress
        return
    }

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $executablePath
    $startInfo.WorkingDirectory = $workingDirectory
    # Keep the game independent of the invoking shell's redirected output pipes.
    $startInfo.UseShellExecute = $true
    # These fixed arguments contain no whitespace or quotes; Arguments also works in PowerShell 5.1.
    $startInfo.Arguments = $gameArguments -join ' '
    if ($Hidden) {
        $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    }

    [IO.File]::WriteAllText($steamAppIdPath, '1361210', [Text.Encoding]::ASCII)
    $process = [Diagnostics.Process]::Start($startInfo)
    if ($null -eq $process) {
        throw 'Darktide process was not created.'
    }
}
else {
    $process = $running[0]
}

try {
    if ($isStart) {
        Write-Output ('STARTED pid={0} hidden={1} path={2}' -f $process.Id, [bool] $Hidden, $executablePath)
    }
    if ($Hidden -or $isWindowAction) {
        Set-GameWindowVisibility -Process $process -Visible ($Action -eq 'Show')
    }
}
finally {
    $process.Dispose()
}
