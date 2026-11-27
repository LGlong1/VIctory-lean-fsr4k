# VIctory lean fork + FSR 4.1.2 at 4K, profiled on an RX 6750 GRE (RDNA2)

This repository starts from
[HypeLobbiesHD/VIctory-RTX3060](https://github.com/HypeLobbiesHD/VIctory-RTX3060)
(a lean, AMD-tuned VIctory line) and adds PC FidelityFX FSR 4.1.2 at 4K. It also
carries the measurements and the fixes this card needed to render correctly.

No game files, keys, executables or DLLs are stored here. Build the runner
yourself and use your own copy of the title.

## Provenance

| Project | Role |
|---|---|
| [HypeLobbiesHD/VIctory-RTX3060](https://github.com/HypeLobbiesHD/VIctory-RTX3060) | the parent of this fork; everything not listed below is its work and its upstreams'. Its own notes are in that repository's README |
| [avatarmanz/VIctory-7900XTX](https://github.com/avatarmanz/VIctory-7900XTX) | where the FSR 4K commit came from (`cd8dfc0`) |
| [DexNom/VIctory](https://github.com/DexNom/VIctory) | the origin of that commit (`ab34a8b2`) |
| [Marvisak/VIctory](https://github.com/Marvisak/VIctory) | the compatibility layer itself |

What this fork adds on top of the parent: the FSR 4.1.2 4K port (`af7798b`),
`scripts/play-fsr4k.ps1`, and the measurements below. Nothing else in the tree
is claimed as new work.

## Measured configuration (RX 6750 GRE 12 GB, Windows 10 22H2)

Test machine: Ryzen 5 5600X, 32 GB DDR4-3200, Radeon RX 6750 GRE 12 GB (RDNA2,
driver 32.0.21045.16010), Windows 10 22H2, 2560x1440 desktop.

Frame rates are medians of the numbers the title prints in its window title,
same save, city street; the draw count of each sample is noted where it
matters.

| Configuration | Frame rate | Picture |
|---|---|---|
| fork defaults (FSR off) | 16-19 fps | character face and some materials black |
| defaults + `VICTORY_CARD_WINDOWS_LEAN=0` | 15 fps | correct |
| same, FSR 4.1.2 `quality` (1440p -> 4K) | 15 fps, 67-75 ms/frame | correct |
| `-Safe` (all fast paths off) | 10-11 fps | correct |

Heavier moments (9k-15k draws) fall to 9-14 fps in every configuration; the
ceiling is the layer's CPU work, not the card, which is why the FSR preset
moves the frame rate by almost nothing and why `performance` (1080p -> 4K) was
not worth keeping.

### Settings used

The parent's `scripts\play.ps1` defaults (relay, card steps, residency,
fallback heaps, renderer ports, list and window tuning) with three changes:

```powershell
VICTORY_CARD_WINDOWS_LEAN=0   # the one that fixes the black character on this card
VICTORY_AMBIENT=0.8
VICTORY_AMBIENT_AIR=0
VICTORY_FSR_4K=quality        # with VICTORY_FIDELITYFX_DIR pointing at AMD's signedbin
```

The parent's `VICTORY_AMBIENT=constant:0.8` with `AMBIENT_AIR=1.5` renders
night scenes too dark on this machine; the per-frame estimate above matches
the newer avatarmanz builds, at no measurable frame-rate cost.

## What was found, and how

Each row below was one run in the same save and spot, changing one group of
settings at a time, with the picture checked at the character's face:

* `VICTORY_CARD_WINDOWS_LEAN=1` (on in the parent's `play.ps1`) draws the
  character's face and some materials **black**. Turning only that switch off
  fixes it; the frame rate stays at ~15 fps with `quality`.
* `VICTORY_THIN` is not the cause: `VICTORY_THIN=0` alone still showed the
  black face (14 fps) while `CARD_WINDOWS_LEAN` stayed on.
* `-Safe` renders correctly only because it also turns `CARD_WINDOWS_LEAN`
  off; it gives up the rest of the fast path (10-11 fps).
* The renderer ports, `INPLACE`, `LIST_LAZY`, `WINDOW_EXACT`,
  `UNDER_WIDE`/`LAND_ECHO`/`UPLOAD_AHEAD` each kept the picture correct in
  their runs.
* A clean clone of this repository built in about a minute and ran the FSR
  `quality` profile for five minutes in the world without a device removal.

The pipelines were then compiled offline: one recording run with
`VICTORY_PIPELINE_BOOK=1`, then `victory shaders <game folder>` and
`victory warm --jobs 6` (83,549 of 83,555 pipelines, 357 seconds here). After
that a run drops no pipeline it has no host pipeline for, and the stutter at
first use is gone.

## How to run

1. Build the runner from this tree:
   `cargo build --release --locked -p victory`.
2. Windows 10 **and 11**: put Microsoft's Agility 1.620.2 `D3D12Core.dll` in
   `target\release\D3D12\` next to the executable. The executable exports
   `D3D12SDKVersion`, so without that folder device creation fails with
   **0x887E0003** on either Windows version. Microsoft's redistributable, not
   stored here.
3. For FSR 4K, take AMD's signed
   `amd_fidelityfx_upscaler_dx12.dll` from the FidelityFX SDK 2.4.0
   (`Kits/FidelityFX/signedbin`) and pass its folder:
   ```powershell
   scripts\play-fsr4k.ps1 -Exe <your copy>\game_scarlett_master.exe -FidelityFx <signedbin> -Preset quality
   ```
4. Persisted data (saves) defaults to `%LOCALAPPDATA%\victory\data`; point
   `VICTORY_DATA_DIR` elsewhere to move it.

## Keyboard and mouse

`VICTORY_KBM_GTA=1` (on by default in `scripts/play-fsr4k.ps1`) puts a GTA V
PC layout on the stand-in gamepad. The pointer starts **unlocked** so menus and
window switching are never trapped: press `F2`, or `` ` `` / `~`, to capture it
for mouse look, and again to let it go. While captured the cursor is hidden
inside the game window; while it is not, mouse buttons are only forwarded when
the pointer is over the game's client area.

| Input | Xbox control | In game |
|---|---|---|
| `W A S D` | Left stick | Move / steer |
| Mouse move; `I J K L` as a fallback | Right stick | Camera / aim |
| `LMB` / `RMB` | RT / LT | Shoot or accelerate / aim or brake-reverse |
| `Shift` / `Enter` | A | Sprint / menu confirm |
| `Space` / `X` | X | Jump, climb, vault |
| `R` / `Backspace` | B | Reload, melee / menu back |
| `F` | Y | Enter or leave a vehicle |
| `Tab` | LB | Weapon wheel |
| `Q` | RB | Take cover / handbrake |
| `Ctrl` | L3 | Crouch, stealth, horn |
| `C`, `MMB`, `CapsLock`, `H` | R3 | Look behind / special |
| `E`; arrows; `M`, `Z`, `G` | D-pad | Interact, phone, minimap or character wheel |
| `V` | View | Change camera |
| `Esc` / `P` | Menu | Pause menu or map (also releases the pointer) |

Extra settings:

* `VICTORY_MOUSE_SENS` - mouse camera sensitivity multiplier (default `1.0`).
* `VICTORY_MOUSE_INVERT_Y=1` - invert the vertical axis.
* `-More @{VICTORY_KBM_GTA='0'}` on the launcher - back to the pad table and
  the plain keyboard bindings.

The mapping is from [Belobug PR #295](https://github.com/Belobug/VIctory-Belobug-AMD/pull/295).
## Frame generation (not in this build)

An AMD frame generation port from [SlaktarnVI](https://github.com/Slaktarn700/SlaktarnVI)
lives on the [feat/texport branch](https://github.com/LGlong1/VIctory-lean-fsr4k/tree/feat/texport) only: on this base it doubles the
shown rate (14-15 real, 27-29 shown) but lets a few faces and textures come
out black at some view angles, and the patch that was to fix it makes the
device go away within a minute. It needs SlaktarnVI's newer texture-slot
machinery, which this base does not have. The profile here is FSR 4.1.2 at 4K
without frame generation.
## NVIDIA

FSR is **off by default** and must stay off on NVIDIA: the PC upscaler is
AMD's and the FSR4 path needs AMD's driver. The parent fork was developed on
an RTX 3060, so the rest of the tree runs there; its own README has those
notes and numbers.

## Limits

One machine only (the one above), Windows 10. No ray tracing was measured.
15 fps is enough to look around, not to play the game through. FSR4 is
temporal and can ghost edges at these frame rates; 4K output changes the UI
size.

## License

GPL-3.0-or-later, as the whole VIctory line; see `LICENSE`. No game assets,
no binaries. If you are one of the authors above and something here is
misattributed, open an issue and it will be corrected.