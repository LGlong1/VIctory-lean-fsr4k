# An unattended run of the title: started with play.ps1's settings, driven by scripted keys,
# frames saved as PNG, stopped after a time, and its log summed up.
#   scripts\autotest.ps1 -Exe <your copy's executable> [-Name cutscene] [-Seconds 300]
#       [-Keys '20:Enter,25:Enter'] [-RayTracing] [-Safe] [-More @{VICTORY_X='1'}]
#       [-CaptureEvery 150] [-Console series-s]
# Everything goes to <data>\runs\<name>-<time>\: log.txt, frames\frame-<n>.png, summary.txt.
# The data folder is victory.toml's data_dir's parent (E:\Dev\victory-data here), or -Out.
# Default keys: Enter every 5 s from 15 s to 4 min (through the splash, the start screen and
# the story-mode prompts; a cutscene is not skipped by it).
param(
    [Parameter(Mandatory)][string]$Exe,
    [string]$Name = 'run',
    [int]$Seconds = 300,
    # Stop once the log has this many frame lines (about 5 s each) of 500 draws or more: a scene,
    # not a menu or a loading screen. 0: run for -Seconds.
    [int]$SceneLines = 10,
    [string]$Keys = '',
    [switch]$RayTracing,
    [switch]$Safe,
    [hashtable]$More = @{},
    [int]$CaptureEvery = 150,
    [ValidateSet('series-x', 'series-s')][string]$Console = 'series-x',
    [string]$Out = 'E:\Dev\victory-data\runs'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$run = Join-Path $Out ("{0}-{1}" -f $Name, (Get-Date -Format 'MMdd-HHmmss'))
New-Item -ItemType Directory -Force (Join-Path $run 'frames') | Out-Null
$log = Join-Path $run 'log.txt'

if (-not $Keys) {
    $Keys = ((15..240 | Where-Object { $_ % 5 -eq 0 }) | ForEach-Object { "${_}:Enter" }) -join ','
}
# Frames saved: powers of two (built in) and every $CaptureEvery-th up to frame 30000.
$frames = ((1..[int](30000 / $CaptureEvery)) | ForEach-Object { $_ * $CaptureEvery }) -join ','
$settings = @{
    VICTORY_KEYS = $Keys
    VICTORY_CAPTURE = (Join-Path $run 'frames')
    VICTORY_CAPTURE_FRAMES = $frames
    VICTORY_PIPELINE_BOOK = '1'
}
foreach ($k in $More.Keys) { $settings[$k] = $More[$k] }
$literal = ($settings.GetEnumerator() | ForEach-Object { "'{0}'='{1}'" -f $_.Key, ($_.Value -replace "'", "''") }) -join ';'
$flags = @()
if ($RayTracing) { $flags += '-RayTracing' }
if ($Safe) { $flags += '-Safe' }
$flags += "-Console $Console"
# One log line per line, UTF-8: a redirect with *> writes UTF-16 and wraps the runtime's
# lines (its stderr) at the console's width, which no line-wise reading survives.
$command = "& '{0}' -Exe '{1}' {2} -More @{{{3}}} *>&1 | ForEach-Object {{ `"`$_`" }} | Out-File -Encoding utf8 -Width 4096 '{4}'" -f (Join-Path $root 'scripts\play.ps1'), $Exe, ($flags -join ' '), $literal, $log
Set-Content (Join-Path $run 'command.txt') $command

$before = @(Get-Process victory -ErrorAction SilentlyContinue | ForEach-Object Id)
$shell = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $command -PassThru -WindowStyle Minimized
$started = Get-Date
$ended = "time ($Seconds s)"
$sceneLine = 'INFO victory_gpu::host: [\d.]+ fps, [\d.]+ ms/frame \([^)]*\), (\d+) draws/frame'
while (((Get-Date) - $started).TotalSeconds -lt $Seconds) {
    Start-Sleep -Seconds 5
    if ($shell.HasExited) { $ended = 'the title ended'; break }
    if ($SceneLines -gt 0 -and (Test-Path $log)) {
        # (read with sharing: the run is still writing it)
        $stream = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
        $now = (New-Object System.IO.StreamReader($stream)).ReadToEnd(); $stream.Close()
        $scene = @([regex]::Matches($now, $sceneLine) | Where-Object { [int]$_.Groups[1].Value -ge 500 }).Count
        if ($scene -ge $SceneLines) { $ended = "$scene frame lines of a scene"; break }
        if ($now -match 'host GPU device removed') { $ended = 'the card was lost'; Start-Sleep -Seconds 5; break }
    }
}
# Stop what this run started (the runtime and its shell), nothing else.
Get-Process victory -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id } | Stop-Process -Force -ErrorAction SilentlyContinue
if (-not $shell.HasExited) { Stop-Process -Id $shell.Id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2

$summary = & (Join-Path $PSScriptRoot 'runsummary.ps1') -Run $run -Ended ("by {0} after {1:N0} s" -f $ended, ((Get-Date) - $started).TotalSeconds)
$summary | Select-Object -First 6
$summary | Select-Object -Last 24
