# VIctory-NV: project status

The living record of this fork: where it stands, what is broken, what is next.
**Every agent and every person working here updates this file when something
changes** (a fix lands, a run is measured, a plan changes). Newest facts win;
old ones are corrected, not left beside the new.

Last updated: 2026-11-26 (session 1, after the 0x119 reboot).

## Goal

The best NVIDIA build of the VIctory recompiler (Xbox Series build of GTA VI →
native Windows/D3D12), competitive on the PortWatch VI tracker
(<https://portwatch-vi.xyz>): playable, 20-30 fps, stable, lit like the console.
Target machine: i5-11400F (6 cores / 12 threads), 24 GB RAM, RTX 3060 12 GB,
Windows 11 22000. Title dump: Series v1.0.2.1, the user's own.

## Layout

| Place | What |
|---|---|
| `E:\Dev\VIctory-NV` | main checkout, branch `nvidia` (what we ship) |
| `E:\Dev\VIctory-merge` | worktree, branch `merge/fxceless`: where work and builds happen; `nvidia` is fast-forwarded to it |
| `E:\Dev\VIctory-fxceless` | worktree at fxceless/main (detached), for A/B runs |
| `E:\Dev\victory-data` | cache, saves, logs (`logs\`), DXIL dumps; `victory.toml` points here |
| `E:\Games\GTA6.Xbox.v1.0.2.1` | the user's dump (never committed, never copied into a repo) |

Remotes: `origin` avatarmanz/VIctory-7900XTX (our base), `upstream`
Marvisak/VIctory, `fxceless`, `dexnom`, `belobug`.

## Where it stands (RTX 3060)

| Stage | State |
|---|---|
| Boot, splash, menus, loading screens | 30 fps, ~33 ms/frame |
| Intro video | **fixed** (cool_fox's per-list movie-plane uploads) |
| Opening cutscene | renders lit (faces, interiors, street) on Series S with pair meetings off; **2-3.5 fps** (280-650 ms/frame) |
| Gameplay | not reached in a test run yet |
| Stability | pair meetings on: the card hung within seconds of the world (3 TDRs), then the PC bugchecked 0x119 during `warm`. Pair meetings are **off by default** since 1005 |
| Lighting | lit without the BVH builder for the cutscene; builder runs need pair meetings (opt-in) |
| Memory | Series X: 20-25 GB private at the cutscene on a 24 GB PC (free RAM < 1 GB, paging, 2-7 s frames); Series S: 15-21 GB |

## Done (session 1)

- Base: avatarmanz/VIctory-7900XTX, + Belobug 81ebb7b, + selected fxceless
  commits (see `docs/fxceless-merge-decisions.md`), + avatarmanz updates to afe6ea1.
- `f5c60ea`: textures the title paints through another view (video planes) are
  looked at every frame while they change (`VICTORY_PAINTED_FRAMES`).
- Removal report: memory at the moment of a device loss; Present's error said.
- **Wave64 on 32-lane hosts** (e4ac42f, translator version 1001):
  console wave64 programs whose LDS is read and written inside a lane branch kept
  `WaveSize(64)`, which NVIDIA refuses (E_INVALIDARG): 9 of the 52 ray-tracing
  structure builder programs and 29 game compute shaders (LocalLights,
  TransmissionVolumetrics, sr_tracing tiling, particles, decals, ...). Fix:
  - `Module::spin_until` / `lower_spins` (emit/bitcode.rs): a wait on an LDS
    counter, emitted straight-line and made a loop after lowering; gives up after
    2^20 reads so a broken meeting costs data, not the card.
  - `Lower::meet` (emit/lower.rs): the two host waves of a console wave meet by
    themselves (per-console-wave counter) instead of at group barriers.
    **Opt-in since 1005 (`VICTORY_PAIR_MEET=1`)**: on by default it hung the card in
    `scattering_transmittance_system` programs. 1004 keeps the wave together in the
    wait (each lane's atomic read could differ, splitting the warp inside the spin);
    1003 lowered the give-up cap to 2^14 reads. Not yet re-tested in game.
  - `widen` allowed for groups of several console waves when pair meetings are on
    (`VICTORY_WAVE_WIDE=0`/`1` to force); 64-thread groups only with `=1`.
  - Result: builder 52/52 pipelines accepted on the 3060 (was 43); game compute
    shaders needing wave64 29 → 1 (+2 that now exceed 32 KiB of LDS).
  - GPU test: `wave64_tests::a_wave_or_inside_a_lane_branch_in_a_group_of_four_console_waves`.
- **CGBJ cool_fox merged** (see `docs/coolfox-merge-decisions.md`; translator
  version 1002): movie-plane uploads (likely fixes the intro rewind), blocking
  fence waits with `WaitOnAddress` (CPU), `TablePlan` (CPU), no RT-resolve
  pipelines without the builder, first-scene pipelines early, residency guard and
  low-commit back-off (memory), Series S two-plane compose, XMA audio fixes.
  Our wave64 lowering kept as the default over theirs.
- `scripts\play.ps1` / `autotest.ps1`: `-Console series-s` (cool_fox runs the
  Series S profile: lower resolution, less memory).

## Open issues (most important first)

1. **CPU: write-watch askings.** The game writes ~2,200 pages (9 MB) a frame; to find
   them the runtime asks Windows about 1.2 GB (`GetWriteWatch`, ~61-180 ns a page):
   **73-790 ms a frame** ("watch(ms)" in run summaries). Fix: guard pages (read-only,
   a fault per page written) for private memory that is rarely written, as view
   memory already does (`watch.rs`). Care: Windows' own writes into title memory
   (file reads) cannot fault the way the title's do.
2. **Memory / paging.** 15-25 GB private on a 24 GB PC; free RAM < 1 GB for most
   of the cutscene, frames of 2-7 s. Host copies of title memory 3.9 GB (2.8 GB
   "windows" outside buffers), shared buffers 4.1 GB, host textures 5.2 GB. First
   lever: `VICTORY_INPLACE=1` (windows opened in place, no copy: less memory, less
   watching and copying). Series S profile.
3. **CPU: preparing 140-350 ms a frame**, of it copies 40-120 ms (~100 MB),
   refreshes ~130 ms (4,346 of 5,302 known to copy nothing), copy-back 60-100 ms.
4. **Pair meetings hang the card** (opt-in now): re-test 1004's uniform wait with
   `VICTORY_PAIR_MEET=1` on Series S, short run, before turning on.
5. **71 mesh shaders (ped skinning) fail DXIL validation**: vertex + primitive
   output > 32 KiB.
6. Wave64 leftovers without pair meetings: 23 64-thread compute programs dropped
   ("no wave32 lowering"), the builder's 9.

## Plans (in order)

1. Build 1005 (pair meetings opt-in), tests, retranslate, `warm --used --jobs 4`.
2. Series S run, then the same with `VICTORY_INPLACE=1`: memory and watch time.
3. Guard pages for rarely written private memory (issue 1): the biggest CPU cost.
4. Refresh overhead for refreshes known to copy nothing (issue 3).
5. Re-test pair meetings (1004's uniform wait), short Series S run; then the builder
   (`-RayTracing`).

## Unattended runs

`scripts\autotest.ps1 -Exe <game>\game_scarlett_master.exe -Name <name> [-Seconds 300]
[-SceneLines 10] [-Console series-s] [-RayTracing] [-More @{...}]`: starts the title
with play.ps1's settings, presses Enter every 5 s from 15 s to 4 min (`VICTORY_KEYS`),
saves frames as PNG every 150 frames (`VICTORY_CAPTURE`), and stops by itself once
the log has `-SceneLines` frame lines (~5 s each) of 500+ draws, when the card is
lost, or after `-Seconds`. The log is UTF-8, one line each (a `*>` redirect writes
UTF-16 wrapped at 120 columns). `scripts\runsummary.ps1 -Run <folder>` writes
`summary.txt`: per frame line fps, ms, preparing, copies, textures, GPU, copy-back,
**watch ms**, draws, dropped, private/free MB; the scene's median; peak memory.

**Safety:** a run that hangs the card costs a driver reset (TDR); three in a row
were followed by a bugcheck (0x119) on this PC. Keep runs short, change one thing at
a time, use `warm --jobs 4`, and do not build while a run is going (RAM).

## Measurements log

| Date | Build | Scene | Result |
|---|---|---|---|
| 2026-11-26 | afe6ea1 + warm | menus | 30 fps, 33 ms |
| 2026-11-26 | afe6ea1 + warm | opening cutscene | 1-3 fps, dark, renders geometry |
| 2026-11-26 | 1002 (pair meet on), Series X | world load | card hung at 72 s; 19.8 GB private, 1.9 GB free |
| 2026-11-26 | 1002, Series S | world load | card hung at 62 s (scattering_transmittance_system) |
| 2026-11-26 | 1003, Series S, `VICTORY_PAIR_MEET=0` | opening cutscene | lit; 2-3.5 fps, preparing 140-350 ms, watch 20-790 ms, 19-21 GB private |
