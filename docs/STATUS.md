# VIctory-NV: project status

The living record of this fork: where it stands, what is broken, what is next.
**Every agent and every person working here updates this file when something
changes** (a fix lands, a run is measured, a plan changes). Newest facts win;
old ones are corrected, not left beside the new.

Last updated: 2026-11-26 (session 1).

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
| Intro video | plays but jumps back and forth ("rewind"); cause not found yet |
| Opening cutscene | renders the scene (street, lamps, characters as silhouettes) but dark; 1-3 fps |
| Gameplay | not reached in a test run yet |
| Lighting | dark: ray-traced light needs the BVH builder, which could not run on NVIDIA until the wave64 work below (not yet tested in game) |
| Memory | fork uses 40-46 GB private; commit limit here ~44 GB |

## Done (session 1)

- Base: avatarmanz/VIctory-7900XTX, + Belobug 81ebb7b, + selected fxceless
  commits (see `docs/fxceless-merge-decisions.md`), + avatarmanz updates to afe6ea1.
- `f5c60ea`: textures the title paints through another view (video planes) are
  looked at every frame while they change (`VICTORY_PAINTED_FRAMES`).
- Removal report: memory at the moment of a device loss; Present's error said.
- **Wave64 on 32-lane hosts (uncommitted at time of writing, see below):**
  console wave64 programs whose LDS is read and written inside a lane branch kept
  `WaveSize(64)`, which NVIDIA refuses (E_INVALIDARG): 9 of the 52 ray-tracing
  structure builder programs and 29 game compute shaders (LocalLights,
  TransmissionVolumetrics, sr_tracing tiling, particles, decals, ...). Fix:
  - `Module::spin_until` / `lower_spins` (emit/bitcode.rs): a wait on an LDS
    counter, emitted straight-line and made a loop after lowering; gives up after
    2^20 reads so a broken meeting costs data, not the card.
  - `Lower::meet` (emit/lower.rs): the two host waves of a console wave meet by
    themselves (per-console-wave counter) instead of at group barriers
    (`VICTORY_PAIR_MEET=0`: off).
  - `widen` allowed for groups of several console waves, and on by default
    (`VICTORY_WAVE_WIDE=0`/`1` to force); 64-thread groups use pair meetings in
    their wave-wide forms (`with_wide_meetings`).
  - Result: builder 52/52 pipelines accepted on the 3060 (was 43); game compute
    shaders needing wave64 29 → 1 (+2 that now exceed 32 KiB of LDS).
  - GPU test: `wave64_tests::a_wave_or_inside_a_lane_branch_in_a_group_of_four_console_waves`.

## Open issues (most important first)

1. **Lighting dark on NVIDIA.** Next: warm with the new translator, run with
   `scripts\play.ps1 -RayTracing` (VICTORY_BVH_BUILDER=1), look at frames.
2. **Frame rate.** CPU-bound: one thread prepares submissions (fxceless measured
   ~70 ms + 13 ms per 1,000 draws on a 14700KF). 6 cores here. See Plans.
3. **Intro video rewinds.** 0 bytes of textures uploaded during the intro: the
   video reaches the card in place. Suspect a fence signalled early so Bink
   overwrites a frame still shown. Not fixed.
4. **71 mesh shaders (ped skinning) fail DXIL validation**: vertex + primitive
   output > 32 KiB. May draw nothing on NVIDIA.
5. **Memory 40-46 GB.** CGBJ claims 8-10 GB.
6. Wave64 leftovers: `vfx_triangleClip:CS_CollectTriangles(_Meshlets)` (title
   uses exactly 32 KiB of LDS, no room for split-wave bookkeeping); one widened
   program refused with "a descriptor neither loaded nor built".
7. 6 untranslatable NVIDIA-only builder programs from session start are now
   translated (part of the wave64 fix); verify in game.

## Plans (in order)

1. Commit the wave64 work; retranslate (`victory shaders ...`), `victory warm --used`.
2. Assess CGBJ's now-public NVIDIA build (`codec-d/cool_fox`, GPL-3.0, ~25 fps,
   8 GB RAM): read source only, decide commit by commit like the fxceless merge.
3. CPU cost of the submission path: make the hot code cheaper, move work to the
   GPU where it is a better fit, avoid work that is redone each frame.
4. Unattended test harness (`scripts\autotest.ps1`): `VICTORY_KEYS` for input,
   `VICTORY_CAPTURE` for PNG frames, timed run, summary of the log.
5. Lighting with the builder on; then the mesh output limit; then memory.

## Measurements log

| Date | Build | Scene | Result |
|---|---|---|---|
| 2026-11-26 | afe6ea1 + warm | menus | 30 fps, 33 ms |
| 2026-11-26 | afe6ea1 + warm | opening cutscene | 1-3 fps, dark, renders geometry |
