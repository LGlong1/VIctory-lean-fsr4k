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
$command = "& '{0}' -Exe '{1}' {2} -More @{{{3}}} *> '{4}'" -f (Join-Path $root 'scripts\play.ps1'), $Exe, ($flags -join ' '), $literal, $log
Set-Content (Join-Path $run 'command.txt') $command

$before = @(Get-Process victory -ErrorAction SilentlyContinue | ForEach-Object Id)
$shell = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $command -PassThru -WindowStyle Minimized
$started = Get-Date
$ended = 'time'
while (((Get-Date) - $started).TotalSeconds -lt $Seconds) {
    Start-Sleep -Seconds 5
    if ($shell.HasExited) { $ended = 'the title ended'; break }
}
# Stop what this run started (the runtime and its shell), nothing else.
Get-Process victory -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id } | Stop-Process -Force -ErrorAction SilentlyContinue
if (-not $shell.HasExited) { Stop-Process -Id $shell.Id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2

# The summary: frame rate over time, what was dropped, refused, lost.
$text = if (Test-Path $log) { Get-Content $log -Raw } else { '' }
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("run      $run")
$lines.Add("ended    by $ended after {0:N0} s" -f ((Get-Date) - $started).TotalSeconds)
$fps = [regex]::Matches($text, '(?m)^\S+T(\d\d:\d\d:\d\d)\.\d+Z\s+INFO victory_gpu::host: ([\d.]+) fps, ([\d.]+) ms/frame \(([\d.]+) preparing.*?; ([\d.]+) on the GPU; ([\d.]+) copying back[^)]*\), (\d+) draws/frame, dropped (\d+) without a host pipeline \((\d+) being made\)', 'Singleline')
$lines.Add("frames   $($fps.Count) frame lines")
$lines.Add("time     fps   ms/frame  preparing  gpu  copyback  draws  dropped(making)")
foreach ($m in $fps) {
    $g = $m.Groups
    $lines.Add(("{0} {1,5} {2,9} {3,10} {4,4} {5,9} {6,6} {7,6}({8})" -f $g[1].Value, $g[2].Value, $g[3].Value, $g[4].Value, $g[5].Value, $g[6].Value, $g[7].Value, $g[8].Value, $g[9].Value))
}
$world = @($fps | Where-Object { [int]$_.Groups[7].Value -ge 500 })
if ($world.Count) {
    $ms = $world | ForEach-Object { [double]$_.Groups[3].Value } | Sort-Object
    $lines.Add(("scenes   {0} lines with 500+ draws: median {1} ms/frame ({2:N1} fps), best {3} ms" -f $world.Count, $ms[[int]($ms.Count / 2)], (1000 / $ms[[int]($ms.Count / 2)]), $ms[0]))
}
foreach ($p in 'host pipeline refused', 'device removed', 'DEVICE_REMOVED', 'when the host device went', 'panicked', 'crash') {
    $n = ([regex]::Matches($text, [regex]::Escape($p))).Count
    if ($n) { $lines.Add("found    $n x '$p'") }
}
$refused = [regex]::Matches($text, 'host pipeline refused[^\[]*\[\s*\w+ ([0-9a-f]{16})') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
if ($refused) { $lines.Add("refused  " + ($refused -join ' ')) }
$warns = [regex]::Matches($text, '(?m)^\S+\s+(WARN|ERROR) (\S+): ([^\r\n]{0,90})') | ForEach-Object { "$($_.Groups[1].Value) $($_.Groups[2].Value): $($_.Groups[3].Value -replace '\d+', 'N')" } | Group-Object | Sort-Object Count -Descending | Select-Object -First 15
foreach ($w in $warns) { $lines.Add(("warn     {0,5} x {1}" -f $w.Count, $w.Name)) }
$pngs = @(Get-ChildItem (Join-Path $run 'frames') -Filter *.png -ErrorAction SilentlyContinue)
$lines.Add("pictures $($pngs.Count) in frames\ (newest: $(($pngs | Sort-Object LastWriteTime | Select-Object -Last 1).Name))")
$lines | Set-Content (Join-Path $run 'summary.txt')
$lines | Select-Object -First 8
$lines | Select-Object -Last 22
