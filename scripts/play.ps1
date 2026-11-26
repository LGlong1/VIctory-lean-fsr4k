# Starts the title with the settings this fork is played with (README.md, "How to run it").
#   scripts\play.ps1 -Exe <path of your own copy's executable>
# -Safe         without the newer, faster ways (the first thing to try when something is wrong)
# -RayTracing   the title's own ray-traced indirect light: lit interiors, about a third slower
# -Build        target\diag (the default, the build all measurements are of) or target\release
# -More         other settings: -More @{VICTORY_PANEL='1'}
# -Console      series-x (the default) or series-s (the smaller console: less memory, a lower resolution)
# Run it from a normal window, not as administrator: the driver then keeps its shader cache elsewhere.
param(
    [Parameter(Mandatory)][string]$Exe,
    [switch]$Safe,
    [switch]$RayTracing,
    [ValidateSet('diag', 'release')][string]$Build = 'diag',
    [hashtable]$More = @{},
    [ValidateSet('series-x', 'series-s')][string]$Console = 'series-x'
)
$settings = @{
    VICTORY_TEXTURE_NO_WAIT = '1'; VICTORY_RELAY = '2'; VICTORY_WIDE_BACK = '1'; VICTORY_CARD_REHASH_RUNS = '1'
    VICTORY_JOIN_COPIES = '1'; VICTORY_INDIRECT_WINDOW = '1'; VICTORY_RELAY_COPY = '1'; VICTORY_CARD_STEPS = '2'
    VICTORY_INDIRECT_BATCH = '2'; VICTORY_MAP_THREADS = '1'; VICTORY_TITLE_PRIORITIES = '0'; VICTORY_CARD_AWAKE = '1'
    VICTORY_SHOW_AFTER = '1'; VICTORY_AMBIENT = '0.8'; VICTORY_D3D12_DRED = 'light'
    # The cool_fox pieces this fork ran with and measured on an RTX 3060 / 24 GB PC (off
    # by default upstream): residency budgets for limited RAM, fallback heaps, the heap
    # buffer pass per heap, XMA voices refilled.
    VICTORY_RESIDENCY = '1'; VICTORY_FALLBACK_HEAPS = '1'; VICTORY_SWEEP_PER_HEAP = '1'; VICTORY_XMA_REFILL = '1'
    # Measured best on the RTX 3060 / 24 GB PC (docs/STATUS.md, 2026-11-26): the page pool
    # committed and what of it can be read in place (any Windows 10+), avatarmanz's renderer
    # patches 1, 2, 5, 6, 7, and host lists taken only at the title's reset. 2.8 -> 4.1 fps
    # median in the opening cutscene (Series S), ~0.75 GB less private memory.
    VICTORY_POOL_COMMIT = '1'; VICTORY_INPLACE = '1'; VICTORY_LIST_LAZY = '1'; VICTORY_WINDOW_EXACT = '1'
    VICTORY_PORT_CONSTANTS = '1'; VICTORY_PORT_DESCRIPTORS = '1'; VICTORY_PORT_CBV = '1'
    VICTORY_PORT_GUARD = '1'; VICTORY_PORT_JOURNAL = '1'
}
if ($Safe) {
    foreach ($k in 'VICTORY_POOL_COMMIT', 'VICTORY_INPLACE', 'VICTORY_LIST_LAZY', 'VICTORY_WINDOW_EXACT', 'VICTORY_PORT_CONSTANTS', 'VICTORY_PORT_DESCRIPTORS', 'VICTORY_PORT_CBV', 'VICTORY_PORT_GUARD', 'VICTORY_PORT_JOURNAL') { $settings.Remove($k) }
    $settings.VICTORY_UNDER_WIDE = '0'; $settings.VICTORY_LAND_ECHO = '0'
} else {
    $settings.VICTORY_THIN = '1'; $settings.VICTORY_JOIN_PARTS = '8'; $settings.VICTORY_UPLOAD_AHEAD = '1'
}
if ($RayTracing) { $settings.VICTORY_BVH_BUILDER = '1' }
foreach ($k in $More.Keys) { $settings[$k] = $More[$k] }

$victory = Join-Path $PSScriptRoot "..\target\$Build\victory.exe"
if (-not (Test-Path $victory)) { Write-Host "No $victory. Build it first (README.md)."; exit 1 }
if (-not (Test-Path $Exe)) { Write-Host "No $Exe."; exit 1 }
# (Other settings left over in this window go; where your files are stays.)
$paths = 'VICTORY_CONFIG', 'VICTORY_GAME_DIR', 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR'
$inherited = @(Get-ChildItem Env:VICTORY_* | Where-Object { $_.Name -notin $paths })
foreach ($entry in $inherited) { Remove-Item "Env:$($entry.Name)" }
foreach ($k in $settings.Keys) { Set-Item "Env:$k" $settings[$k] }
$discarded = $inherited | Where-Object {
    $_.Name -notin $More.Keys -and -not $_.Value.Equals([Environment]::GetEnvironmentVariable($_.Name))
} | Sort-Object Name
if ($discarded) {
    Write-Host "Discarded inherited values for $($discarded.Name -join ', '). Use -More to pass them explicitly."
}
$Exe = (Resolve-Path $Exe).Path
Push-Location (Join-Path $PSScriptRoot '..')   # victory.toml is looked for here
try { & $victory run $Exe --console $Console --execute } finally { Pop-Location }
