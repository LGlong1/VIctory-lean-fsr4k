# Starts this fork with FSR 4.1.2 at 4K (AMD only: the signed PC upscaler is
# AMD's; NVIDIA users should keep VICTORY_FSR_4K unset and use play.ps1).
#
#   scripts\play-fsr4k.ps1 -Exe <executable> -FidelityFx <signedbin folder>
#                          [-Preset quality|balanced|performance]
#
# -FidelityFx is the folder holding amd_fidelityfx_upscaler_dx12.dll from the
# FidelityFX SDK 2.4.0 (Kits/FidelityFX/signedbin). Not stored here.
param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$FidelityFx,
    [ValidateSet('quality', 'balanced', 'performance')][string]$Preset = 'quality',
    [hashtable]$More = @{}
)
$dll = Join-Path $FidelityFx 'amd_fidelityfx_upscaler_dx12.dll'
if (-not (Test-Path $dll)) {
    Write-Error "amd_fidelityfx_upscaler_dx12.dll not found in $FidelityFx"
    exit 2
}
$settings = @{
    VICTORY_FSR_4K = $Preset
    VICTORY_FIDELITYFX_DIR = $FidelityFx
    # play.ps1's constant ambient (VICTORY_AMBIENT=constant:0.8, AMBIENT_AIR=1.5)
    # renders night scenes with characters and railings in near-black on this
    # machine; the per-frame estimate matches the newer avatarmanz builds.
    VICTORY_AMBIENT = '0.8'
    VICTORY_AMBIENT_AIR = '0'
    # GTA V style keyboard and mouse (Belobug PR #295); F2 or ` / ~ locks the
    # mouse look. Pass -More @{VICTORY_KBM_GTA='0'} to turn it off.
    VICTORY_KBM_GTA = '1'
}
foreach ($k in $More.Keys) { $settings[$k] = $More[$k] }
& "$PSScriptRoot\play.ps1" -Exe $Exe -Build release -More $settings