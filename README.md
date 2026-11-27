# VIctory on an RTX 3060

A fork of [VIctory](https://github.com/Marvisak/VIctory), a compatibility layer
that runs an Xbox Series title natively on Windows from files the user supplies,
tuned for an **NVIDIA GeForce RTX 3060 12 GB** on a mid-range PC.

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
