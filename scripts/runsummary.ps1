# Sums up a run's log (scripts\autotest.ps1 writes one): the frame rate over time, where a
# frame's time went, memory, what was refused or lost.
#   scripts\runsummary.ps1 -Run <run folder>        (writes summary.txt there and prints it)
param([Parameter(Mandatory)][string]$Run, [string]$Ended = '')
$log = Join-Path $Run 'log.txt'
$text = if (Test-Path $log) { Get-Content $log -Raw } else { '' }
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("run      $Run")
if ($Ended) { $lines.Add("ended    $Ended") }
$frame = '(?m)^\S+T(\d\d:\d\d:\d\d)\.\d+Z\s+INFO victory_gpu::host: ([\d.]+) fps, ([\d.]+) ms/frame \(([\d.]+) preparing: copies ([\d.]+) ms [\d.]+ MB, textures ([\d.]+) ms [\d.]+ MB; ([\d.]+) on the GPU; ([\d.]+) copying back [\d.]+ MB\), (\d+) draws/frame, dropped ([\d.]+) without a host pipeline \((\d+) being made\)'
$fps = [regex]::Matches($text, $frame)
$watch = [regex]::Matches($text, '(?m)^\S+T(\d\d:\d\d:\d\d)\.\d+Z\s+INFO victory_gpu::copystat: copies per frame: .*? (\d+) watches ([\d.]+) ms, ([\d.]+) MB checked')
$memory = [regex]::Matches($text, '(?m)^\S+T(\d\d:\d\d:\d\d)\.\d+Z\s+INFO victory_gpu::copystat: memory: (\d+) MB private \(\d+ MB of it in memory; the PC has (\d+) MB free')
$watchAt = @{}; foreach ($m in $watch) { $watchAt[$m.Groups[1].Value] = $m }
$memAt = @{}; foreach ($m in $memory) { $memAt[$m.Groups[1].Value] = $m }
$lines.Add("frames   $($fps.Count) frame lines")
$lines.Add("time      fps  ms/frame  prep  copies  tex  gpu  back  watch(ms)  draws  dropped(making)  private/free MB")
foreach ($m in $fps) {
    $g = $m.Groups; $t = $g[1].Value
    $w = if ($watchAt[$t]) { $watchAt[$t].Groups[3].Value } else { '' }
    $mm = if ($memAt[$t]) { "$($memAt[$t].Groups[2].Value)/$($memAt[$t].Groups[3].Value)" } else { '' }
    $lines.Add(("{0} {1,5} {2,9} {3,5} {4,7} {5,4} {6,4} {7,5} {8,10} {9,6} {10,8}({11}) {12}" -f $t, $g[2].Value, $g[3].Value, $g[4].Value, $g[5].Value, $g[6].Value, $g[7].Value, $g[8].Value, $w, $g[9].Value, $g[10].Value, $g[11].Value, $mm))
}
$world = @($fps | Where-Object { [int]$_.Groups[9].Value -ge 500 })
if ($world.Count) {
    $ms = @($world | ForEach-Object { [double]$_.Groups[3].Value } | Sort-Object)
    $prep = @($world | ForEach-Object { [double]$_.Groups[4].Value } | Sort-Object)
    $mid = [int]($ms.Count / 2)
    $lines.Add(("scenes   {0} lines with 500+ draws: median {1} ms/frame ({2:N1} fps), best {3} ms, median preparing {4} ms" -f $world.Count, $ms[$mid], (1000 / $ms[$mid]), $ms[0], $prep[$mid]))
}
if ($memory.Count) {
    $peak = ($memory | ForEach-Object { [int]$_.Groups[2].Value } | Measure-Object -Maximum).Maximum
    $low = ($memory | ForEach-Object { [int]$_.Groups[3].Value } | Measure-Object -Minimum).Minimum
    $lines.Add("memory   peak $peak MB private, lowest $low MB free on the PC")
}
foreach ($p in 'host pipeline refused', 'host GPU device removed', 'DRED device state', 'panicked') {
    $n = ([regex]::Matches($text, [regex]::Escape($p))).Count
    if ($n) { $lines.Add("found    $n x '$p'") }
}
$refused = [regex]::Matches($text, 'host pipeline refused error=(?!The GPU device instance has been suspended)[^\[]*\[\s*\w+ ([0-9a-f]{16})') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
if ($refused) { $lines.Add("refused  " + ($refused -join ' ')) }
$warns = [regex]::Matches($text, '(?m)^\S+\s+(WARN|ERROR) (\S+): ([^\r\n]{0,90})') | ForEach-Object { "$($_.Groups[1].Value) $($_.Groups[2].Value): $($_.Groups[3].Value -replace '\d+', 'N')" } | Group-Object | Sort-Object Count -Descending | Select-Object -First 12
foreach ($w in $warns) { $lines.Add(("warn     {0,5} x {1}" -f $w.Count, $w.Name)) }
$pngs = @(Get-ChildItem (Join-Path $Run 'frames') -Filter *.png -ErrorAction SilentlyContinue)
$lines.Add("pictures $($pngs.Count) in frames\ (newest: $(($pngs | Sort-Object LastWriteTime | Select-Object -Last 1).Name))")
$lines | Set-Content (Join-Path $Run 'summary.txt')
$lines
