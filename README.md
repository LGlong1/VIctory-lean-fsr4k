# VIctory on an RTX 3060 (lean fork) with FSR 4.1.2 at 4K

A fork of [VIctory](https://github.com/Marvisak/VIctory), a compatibility layer
that runs an Xbox Series title natively on Windows from files the user supplies.
It is based on [HypeLobbiesHD/VIctory-RTX3060](https://github.com/HypeLobbiesHD/VIctory-RTX3060)
(lean windows, residency budgets, card-side copies, renderer ports), with FSR
4.1.2 at 4K added and measured on an AMD RDNA2 card.

**This repository contains no game files, code or assets, and no binaries.** You
need your own copy of the game and build the executable yourself. It is not
affiliated with or endorsed by the game's developer or publisher.


## Provenance and credits

This repository is a **fork of
[HypeLobbiesHD/VIctory-RTX3060](https://github.com/HypeLobbiesHD/VIctory-RTX3060)**
at commit `3abb527`. Everything in the tree that is not listed below is that
fork's work and its upstreams': the lean windows, the residency budgets, the
card-side buffer copies, the renderer ports, the loader, the D3D12 back end and
the shader recompiler.

The changes on top of `3abb527` are only these:

* **FSR 4.1.2 at 4K** (`af7798b`), ported from
  [avatarmanz/VIctory-7900XTX](https://github.com/avatarmanz/VIctory-7900XTX)
  commit `cd8dfc0` (by beloooo), which took it from
  [DexNom/VIctory](https://github.com/DexNom/VIctory) `ab34a8b2`.
* **`scripts/play-fsr4k.ps1` and the measured section of this README**
  (`6633100`, `6b2d6aa`).

The upstream chain is [Marvisak/VIctory](https://github.com/Marvisak/VIctory),
[fxceless/victory-fork](https://github.com/fxceless/victory-fork), and the forks
named under Credits at the end of this file. Ideas that came from Belobug,
DexNom, myokex, Kelvaroq, codec-d and the Portwatch forks are credited there
and in the commit messages; none of their code is claimed here.

If you are one of those authors and something in this branch looks wrong,
open an issue or a PR: corrections are welcome.
## Measured on an RX 6750 GRE 12 GB (Windows 10)

Reference machine: Ryzen 5 5600X, 32 GB DDR4-3200, **RX 6750 GRE 12 GB** (RDNA2,
driver 32.0.21045.16010), Windows 10 22H2. Frame rates are read from the
title's window title in a city street; each row's draw count is in the table.

| Run | Settings | Draws | Frame rate |
|---|---|---|---|
| this fork's defaults, no FSR | `scripts\play.ps1` | 2.7k-6.7k | **16-19 fps** |
| FSR 4.1.2 `quality` (1440p rendered, 3840x2160 out) | `scripts\play-fsr4k.ps1 -Preset quality` | 3.5k-5.4k | **15.6-16.8 fps** |
| clean clone of this repository, FSR `quality` | as documented below | 3.3k-4.3k | **16-19 fps**, five minutes, no device removal |

Memory: 24-25 GB private at peak; 2.3 GB of the title's buffers live in the
card's memory (464 copies). Heavy moments (about 9k draws) drop to 5 fps for a
frame or two.

The render resolution barely moves the frame rate on this machine: the layer is
CPU-bound (about 100 ms preparing a frame) and the card finishes behind the
relay. That is why FSR 4K costs so little here compared with the fork's own
1080p-class output.

### Configuration used

This fork's `scripts\play.ps1` defaults, unchanged: `VICTORY_RELAY=2`,
`VICTORY_CARD_STEPS=2`, `VICTORY_INPLACE=1`, `VICTORY_CARD_REHASH_RUNS=1`,
`VICTORY_RESIDENCY=1`, `VICTORY_FALLBACK_HEAPS=1`, `VICTORY_SWEEP_PER_HEAP=1`,
`VICTORY_XMA_REFILL=1`, `VICTORY_LIST_LAZY=1`, `VICTORY_WINDOW_EXACT=1`,
`VICTORY_PORT_CONSTANTS=1`, `VICTORY_PORT_DESCRIPTORS=1`, `VICTORY_PORT_CBV=1`,
`VICTORY_PORT_GUARD=1`, `VICTORY_PORT_JOURNAL=1`, `VICTORY_CARD_WINDOWS_LEAN=1`.
The FSR rows add `VICTORY_FSR_4K=quality` and `VICTORY_FIDELITYFX_DIR` pointing
at AMD's `signedbin` folder.

### What this branch adds

* **FSR 4.1.2 at 4K** (`af7798b`), ported from
  [avatarmanz/VIctory-7900XTX](https://github.com/avatarmanz/VIctory-7900XTX)
  `cd8dfc0` (which took it from DexNom/VIctory `ab34a8b2`). It patches the
  title's Series X SDR 4K profile and serves its FidelityFX calls from AMD's
  signed PC `amd_fidelityfx_upscaler_dx12.dll` (FidelityFX SDK 2.4.0) instead of
  the console one: `provider="4.1.2"`, 2560x1440 rendered, 3840x2160 output.
* **Docs and a launcher** (`6633100`): this section, the requirements below and
  `scripts/play-fsr4k.ps1`.

Everything else in the tree is HypeLobbiesHD's and the upstream forks' work;
see Credits.


### Lighting: use the per-frame estimate, not the constant

`scripts\play.ps1` sets `VICTORY_AMBIENT=constant:0.8` and
`VICTORY_AMBIENT_AIR=1.5`. On the reference machine that renders night scenes
with the character and the lit railings almost black next to the newer
avatarmanz builds; the same save at the same spot with
`VICTORY_AMBIENT=0.8` and `VICTORY_AMBIENT_AIR=0` matches their picture and
leaves the frame rate unchanged within noise (13-17 fps with FSR `quality`).
`scripts/play-fsr4k.ps1` now passes those two values by default; pass `-More`
to override them.### Requirements

| | |
|---|---|
| executable | build it: `cargo build --release --locked -p victory`. No binaries are stored here |
| Windows 10 **and** 11 | put `D3D12Core.dll` 1.620.2 (Microsoft's Agility SDK, redistributable) in `target\release\D3D12\` beside the executable. It exports `D3D12SDKVersion`, so without that folder the device fails with **0x887E0003** on either Windows version |
| FSR 4K | an AMD GPU, and AMD's signed `amd_fidelityfx_upscaler_dx12.dll` from the FidelityFX SDK 2.4.0 `signedbin` folder (not stored here) |
| NVIDIA | **leave FSR off**: do not set `VICTORY_FSR_4K`. The base fork was developed on an RTX 3060, so the rest runs there |

### Clean-clone check

A fresh `git clone` of this repository built with `cargo build --release
--locked -p victory` in 1 m 06 s, and `scripts\play-fsr4k.ps1 -Preset quality`
then ran for five minutes in the world without a device removal: 16-19 fps,
`provider="4.1.2"`, 2560x1440 rendered to 3840x2160 (the third row above).

### Limits and open things

* One machine only (the reference above), Windows 10. Nothing here was tried on
  Windows 11, on NVIDIA, or with ray tracing enabled.
* FSR4 is a temporal upscaler: at 15-19 fps moving edges can ghost, and 4K
  output changes the UI's size. Compare `-Preset quality`, `balanced` and
  `performance` before keeping one.
* A preset's first run compiles its own pipelines; frames before that are
  slower.
* The base fork's own notes (NVIDIA RTX 3060, Series S, 30 fps memory goals) are
  still below in this README.

## How to run with FSR 4K

1. Get AMD's signed upscaler from the FidelityFX SDK 2.4.0 release
   (`Kits/FidelityFX/signedbin/amd_fidelityfx_upscaler_dx12.dll`). This
   repository does not store it.
2. ```powershell
   scripts\play-fsr4k.ps1 -Exe "D:\Games\MyDump\game_scarlett_master.exe" `
       -FidelityFx "D:\FX\signedbin" -Preset quality
   ```
   or set the two variables the layer reads: `VICTORY_FSR_4K=quality` and
   `VICTORY_FIDELITYFX_DIR=<folder>`.
3. Windows 10 and 11 both need the D3D12 Agility runtime beside the executable:
   `target\release\D3D12\D3D12Core.dll` 1.620.2 (Microsoft's redistributable;
   see `apps/victory/src/agility.rs`).

`-Preset balanced` renders 2258x1270 and `performance` 1920x1080, both at 4K
out.
## The goal

**Ray tracing off: a stable 30 fps in 8-10 GB of RAM first.** Then lower frame
times and latency, then ray tracing. The test PC: Intel i5-11400F, 24 GB RAM,
RTX 3060 12 GB, Windows 11 21H2.

The way there is **porting, not emulating**: patching the title's renderer so it
behaves the way a PC renderer does, rather than having the layer watch and copy
the console's shared memory every frame. Shaders are translated ahead of time
into a versioned store that is kept between builds.

**This repository contains no game files, code or assets.** You need your own
copy of the game. It is not affiliated with or endorsed by the game's developer
or publisher. A pre-commit check (`cargo xtask policy`) refuses them.

## Where it stands (2026-11-26)

| | |
|---|---|
| Boot, menus, loading screens, intro video | 30 fps (33 ms) |
| Opening cutscene, Series S profile | renders lit; **3-6.5 fps median** (150-360 ms), best frames 94 ms |
| Memory | about 19 GB private at peak: on a 24 GB PC it pages, and the frame rate follows free RAM (identical runs: 1.6 fps at 47 MB free, 6.0 fps at 1.1 GB free) |
| Gameplay | not reached in a test run yet |

Most of a frame is the CPU preparing the title's work (copies and refreshes of
console memory), not the card. **Cutting RAM is the next step**, then the CPU's
share of the frame. Progress, measurements and plans:
[docs/STATUS.md](docs/STATUS.md). The other forks' pull requests reviewed for
this PC: [docs/pr-review-2026-11-26.md](docs/pr-review-2026-11-26.md).

## How to run it

You need Windows 10/11 x64 (tested on Windows 11 21H2), a CPU with AVX2, a Direct3D 12 GPU with shader
model 6.6 and mesh shaders, Rust (the toolchain is pinned), the MSVC build
tools, and your own dump of the title.

```powershell
git clone https://github.com/HypeLobbiesHD/VIctory-RTX3060
cd VIctory-RTX3060
copy victory.example.toml victory.toml      # then set your paths, outside this folder
cargo build --locked --profile diag -p victory --features diagnostics
scripts\play.ps1 -Exe <path of your copy's executable>
```

`play.ps1` also puts Microsoft's D3D12 Agility SDK runtime next to `victory.exe`
(`D3D12Core.dll`, from the `Microsoft.Direct3D.D3D12` NuGet package, version
1.620.2, unpacked to `VICTORY_AGILITY_DIR`; it is never in this repository). On
older Windows 11 builds it is what lets title memory be read in place.
`-NoAgility` uses the runtime in Windows instead.

`scripts\play.ps1 -Safe` leaves out the newest, faster ways; try it first when
something is wrong. `-RayTracing` turns the title's ray-traced indirect light on.

For PC FSR 4.1.2, set `[paths].fidelityfx_dir` in `victory.toml` or
`VICTORY_FIDELITYFX_DIR` to the folder containing AMD's signed
`amd_fidelityfx_upscaler_dx12.dll`. Use the DirectX 12 upscaler in
`Kits/FidelityFX/signedbin`. [AMD FSR SDK 2.4.0](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/tree/v2.4.0/Kits/FidelityFX/signedbin)

`scripts\play.ps1 -Exe <path> -Fsr4K quality` selects 2560×1440 input for
the retail 1.0.2.1 Series X 4K SDR profile. `balanced` selects 2258×1270
and `performance` selects 1920×1080. All three output 3840×2160. With
`victory run` directly, set `VICTORY_FSR_4K` to the preset name.
The log reports the provider at context creation and the actual input and
output sizes at the first successful temporal dispatch. The title profile
and PC FidelityFX bridge were ported from [DexNom/VIctory](https://github.com/DexNom/VIctory/commit/ab34a8b21477c94da2a6cf07249138e8bc84602e).

On a hybrid-graphics PC, the runtime and offline pipeline checks prefer a
high-performance adapter with Shader Model 6.6. The runtime logs its adapter
name, PCI vendor and device IDs, and dedicated VRAM. Set
`VICTORY_D3D12_ADAPTER` to a zero-based DXGI index or part of the adapter's
name to select it explicitly. With the launcher, pass
`-More @{VICTORY_D3D12_ADAPTER='NVIDIA'}`.

Before the first run, ahead of time (both can be stopped and go on later):

```powershell
target\diag\victory.exe shaders <the shader archives>   # every shader translated, minutes
target\diag\victory.exe warm --used                     # pipelines earlier runs drew with, for a new driver or build
```

Commands, debugging switches and upstream's own description:
[docs/README-fxceless.md](docs/README-fxceless.md). Every `VICTORY_...` switch is
described in a comment where it is read.

## What is different here

NVIDIA-specific, in this fork: 32-lane waves where a shader allows it, descriptor
heaps sized to the driver's 1,000,000 views, title buffers placed in video memory
sized for 10-12 GB cards, a pipeline library per D3D12 runtime, and the Agility
SDK. Taken from the forks below:

In short; the reasons and the measurements are in [docs/findings.md](docs/findings.md).

- **List calls are written down, not carried out, on the title's threads**
  (`VICTORY_THIN`): eight threads of ours translate them.
- **Submissions are prepared by a thread of ours and joined**
  (`VICTORY_ASYNC_SUBMIT`, `VICTORY_JOIN_PARTS`), with what can be spread over
  threads spread: refreshes, compares (AVX2), descriptor records, landings.
- **What shaders wrote comes back beside the write guards**, by the dwords that
  changed, on a thread of its own (`VICTORY_RELAY`, `VICTORY_LAND`).
- **Buffer fills that need bytes still on the card are done on the card**
  (`VICTORY_CARD_STEPS`) instead of waiting for it.
- **The title's writes are caught more cheaply**: one view opened at a fault,
  blocks that rest, places in the title's code that look before they write.
- **Textures go up on a copy queue of their own** and a slot shows one only after
  its upload ran, which also ended a device loss that came every 15 minutes or so.
- **Boats float**: textures that shaders write and the title's CPU reads go back
  to title memory (from fxceless and Geckomacabre, on by default here).
- **Frame record and replay** with per-pass times and shader variants compared
  turn by turn ([docs/replay.md](docs/replay.md)).

## Credits

This is a tree of other people's work with more on top. The history is kept, and
commits taken from elsewhere name the commit and its author.

- **[VIctory](https://github.com/Marvisak/VIctory)** by Marvisak and its
  contributors: the loader, the runtime services, the Direct3D 12 back end and
  the shader recompiler.
- **[avatarmanz/VIctory-7900XTX](https://github.com/avatarmanz/VIctory-7900XTX)**:
  the fork this one is based on (renderer patches, the unattended test harness).
- **[fxceless/victory-fork](https://github.com/fxceless/victory-fork)**: the fork
  avatarmanz's started from, and the people whose pull requests it carries.
- **[DexNom/VIctory](https://github.com/DexNom/VIctory)**: ray tracing fixes,
  cube gradients, sparse textures.
- **[Belobug/VIctory-Belobug-AMD](https://github.com/Belobug/VIctory-Belobug-AMD)**:
  the ambient light idea, pipeline workers, and work by romainhedouin.
- **[FQY55kai/ZJOU-VICTORY](https://github.com/FQY55kai/ZJOU-VICTORY)**.
- **[myokex/victory-amd](https://github.com/myokex/victory-amd)**: the guard over
  every view of a page (with Spexivus, joroyt and tightfall), and Joshua Odom's
  reads into title memory.
- **Geckomacabre** and **cxy0072019-sketch**: the texture read-back.
- **[XCL](https://github.com/ivall/xcl)** (GPL-2.0-only) was read for how the same
  title behaves under another layer; no code of it is here.
- This fork's changes were made with [Claude Code](https://claude.com/claude-code).

## License

GPL-3.0-or-later, as VIctory. See [LICENSE](LICENSE); the one file that is not
covered is named in [docs/asset-policy.md](docs/asset-policy.md).
