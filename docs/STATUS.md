# VIctory-NV: project status

The living record of this fork: where it stands, what is broken, what is next.
**Every agent and every person working here updates this file when something
changes** (a fix lands, a run is measured, a plan changes). Newest facts win;
old ones are corrected, not left beside the new.

Last updated: 2026-11-26 (session 2: Agility SDK, card buffers, PR review, repo HypeLobbiesHD/VIctory-RTX3060).

## Goal

The best NVIDIA build of the VIctory recompiler (Xbox Series build of GTA VI →
native Windows/D3D12), competitive on the PortWatch VI tracker
(<https://portwatch-vi.xyz>): playable, 20-30 fps, stable, lit like the console.
Target machine: i5-11400F (6 cores / 12 threads), 24 GB RAM, RTX 3060 12 GB,
Windows 11 22000. Title dump: Series v1.0.2.1, the user's own.

**Current target (user, 2026-11-26): ray tracing OFF (no `-RayTracing`, no
`VICTORY_BVH_BUILDER`), a stable 30 fps (33 ms), at 8-10 GB private.** Ray tracing
waits until that holds. Every run measured so far was already without ray tracing
(no run's `command.txt` has `-RayTracing`; the builder is off by default). Where it
stands against that: 240 ms median (4.2 fps), 17.6-18.7 GB peak private.

## Layout

| Place | What |
|---|---|
| `E:\Dev\VIctory-NV` | main checkout, branch `nvidia` (what we ship), pushed as `main` to **github.com/HypeLobbiesHD/VIctory-RTX3060** (remote `mine`) |
| `E:\Dev\VIctory-avatar2` | worktree, branch `try/avatar2`: where work, builds and runs happen (since session 2); `nvidia` is fast-forwarded to it |
| `E:\Dev\VIctory-merge` | worktree, branch `merge/fxceless` (behind; was the work tree in session 1) |
| `E:\Dev\VIctory-fxceless` | worktree at fxceless/main (detached), for A/B runs |
| `E:\Dev\victory-data` | cache, saves, logs (`logs\`), DXIL dumps; `victory.toml` points here |
| `E:\Games\GTA6.Xbox.v1.0.2.1` | the user's dump (never committed, never copied into a repo) |

Commits are made as HypeLobbiesHD's GitHub no-reply address (repo `user.email`); the
pre-commit hook (`cargo xtask install-hooks`) runs the asset policy. PR heads of the forks:
`git fetch <remote> "+refs/pull/*/head:refs/prs/<remote>/*"`.

Remotes: `mine` HypeLobbiesHD/VIctory-RTX3060 (ours), `origin` avatarmanz/VIctory-7900XTX (our base), `upstream`
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

## Done (session 2)

- **D3D12 Agility SDK 1.620.2** (`apps/victory/src/agility.rs`, `build.rs`): victory.exe
  exports `D3D12SDKVersion`/`D3D12SDKPath`; `play.ps1` copies Microsoft's DLLs from
  `victory-data\agility\1.620.2` (NuGet `Microsoft.Direct3D.D3D12`, signed, never in the
  repo) to `target\<build>\D3D12\` (`-NoAgility` removes it). **On build 22000 the log now
  says `device13=true opening=Part`**: `ID3D12Device13::OpenExistingHeapFromAddress1`
  without a Windows upgrade, so renderer port 1 opens its 185 MB region in place without a
  section heap. System commit after the run: no leak (lower than before it).
- A pipeline library and the driver's disk cache are good for one D3D12 runtime only: the
  first Agility run found the library rejected (0x887E0002), made every pipeline during the
  cutscene (500-950 draws a frame dropped: **black cutscene, 2.5 fps**) and overwrote the
  196 MB library of the runtime in Windows. Now: the library file is per runtime
  (`host-pipelines-agility.bin` beside `host-pipelines.bin`), and `warm`'s fingerprint
  includes the runtime, so `warm --used` makes them again for the new one. **After a change
  of runtime, `warm --used --jobs 4` before measuring.** The in-box library is lost: a
  `-NoAgility` run needs a warm of its own first.
- **Warm does not stand in for the library** (run `s-agility-warm-1126-150943`, after
  `warm --used`: 2,434 made in 714 s): the library loaded 1,354 pipelines (the in-box one
  had 2,013), and 500-800 stayed "being made" the whole run, ~1-2 a second (made=100 in the
  run). So the driver's disk cache that warm fills is not what made the in-box runs fast:
  the library was, filled over many runs. Cutscene still black in part: 1.9 fps median.
- **What Part reaches** (same run): 78 windows 376 MB + one 174 MB title buffer in place,
  port 1's 185 MB region; port 5: 0 constant buffers in place (585 not in place, 7,734 not
  on 16 bytes). **Still turned down: 746 windows of view memory (the title's page pool,
  2.36 GB "with holes" + 172 MB scattered)**: view memory is a section's mapped views,
  which `OpenExistingHeapFromAddress1` cannot open either. So the Agility SDK takes ~0.5 GB
  off the copies, not the 2.5 GB that matter. No commit left behind (20.2 GB after vs
  20.8 GB before).

- **Forks' open PRs reviewed** for frame rate: `docs/pr-review-2026-11-26.md` (1,470 open,
  159 measured hot-path ones, verdicts and order to try).
- **Card buffers on 10-12 GB cards (avatarmanz#225, taken with our own tier)**: title
  buffers of 1 MiB and up, up to 1,536 MiB, live on the card (was 16 MiB / 512 MiB).
  Runs (Series S cutscene, Agility, warm library): env `MIN_MB=1 MB=1536` **177 ms median
  (5.6 fps), best 120** (`s-cardbuf`); the PR's own 64 KiB minimum 503 ms (`s-pr225`);
  1 MiB built in 768 ms (`s-card1m`). The last two are the same work as the first (same
  watches, ~4.5 GB checked a frame) at 10-20x the time: the checked memory was paged out.
  Settled by the A/B below.
- **Measuring on this PC**: at ~18 GB private, with Opera, Discord and Wallpaper Engine
  holding ~3-4 GB, the run pages and one run per setting swings 2-4x. Compare medians of
  2-3 runs each, other programs closed, and look at "watch(ms)" against "MB checked" to
  see paging.
- **Card buffers settled (A/B, other programs closed, alternating):** 1 MiB / 1,536 MiB
  403 and 176 ms median vs 16 MiB / 512 MiB 968 and 254 ms; copy-back 17 vs 31 ms a frame
  in every run. 1 MiB is the default for 10-12 GB cards (`shadow::default_card_limits`).
  **Best so far: 5.7 fps median, 113 ms best** (`ab-1m-b`). The swing inside each setting
  is paging: the game alone reaches 19 GB, < 400 MB free. RAM is the next lever for frame
  rate too, not only for the 8-10 GB goal.
- Commit read right after a run is high while the process is still ending
  (30.7 GB, 20.9 GB 20 s later): read it once `victory.exe` is gone.

- **Second PR check (217 new or changed PRs)**: hot-path ones with measured numbers taken where
  they apply here: avatarmanz#377 (holes' answers kept 30 frames, `VICTORY_HOLES_ONCE`), #376
  (AVX2 compare in find_pieces, no AddRef/Release per bound slot), #391
  (`VICTORY_WINDOWS_BAR_PCT`), Belobug#62 (descriptor copy finds its heap once per run), #32
  (texture write check without building lists). fxceless#1390 (`VICTORY_EXACT_REUSE`)
  conflicts with our `exact()`: to port. Verdicts in `docs/pr-review-2026-11-26.md`.
- **Card memory the CPU maps is not offered on this PC** (`supported=false`): GPU upload heaps
  need Resizable BAR on (BAR1 is 256 MiB here: off in the BIOS) and Windows 11 24H2
  (build 26080+; this PC is 22000). With both, `VICTORY_WINDOWS_BAR_MB` would take the
  ~3.1 GB of window copies out of the PC's RAM. Until then RAM cuts must come from our side.
- **Frame rate follows free RAM**: four runs of identical code gave 1.6-6.0 fps, in the order
  of the lowest free memory. Every RAM cut is a frame-rate gain on this PC.

- **Build settings and RAM switches** (later the same day): thin LTO and x86-64-v3 from
  Marvisak#3011 kept (A/B was noise). Belobug#373 (`VICTORY_SEND_SPARE_MB`,
  `VICTORY_SCRATCH_SPARE_MB`) and #374 (`VICTORY_STAGING_IDLE_MS`, `VICTORY_WINDOW_IDLE_MS`,
  `VICTORY_READ_KEEP_MB`) taken as switches, off: ~0.4 GB less peak, slower frames. Belobug#372
  is our `VICTORY_LIST_IDLE_MS` already; #386 matters only without `VICTORY_RESIDENCY`.
- **Run-to-run noise beats every small change here**: with 17-19 GB free before a run and
  ~19 GB private at the scene, each run pages differently. Small CPU wins cannot be measured
  until the peak is well under the free RAM; the 8 GB of texture copies and pool and the
  3 GB of window copies are what is big enough to matter.

- **What is really in the PC's memory** (memory map with physical pages, `VICTORY_MEMORY_MAP=6`):
  on this NVIDIA driver the card's own heaps are committed private memory of the process too
  (16 heaps of 64 MiB: +1,026 MB private, nothing in physical memory; `pool::card_heap_cost`), so
  "19 GB private" counts the ~5 GB of textures on the card. In physical memory: ~15 GB, of which
  the title's own heaps and page pool ~8.4 GB, ours ~6.3 GB (window copies ~3 GB the biggest,
  our Rust heap ~1.2 GB, write-combined upload memory ~1.5 GB).
- **Lean windows** (`VICTORY_CARD_WINDOWS_LEAN=1`, now play.ps1's default): windows of title
  memory keep only their card side; a refresh reads the pages the title wrote into a pending
  store and the submission's own memory takes them from there. A: 5.7 / 4.7 fps, B: 5.1 / 4.2;
  preparing 105 / 143 against 155 / 202 ms; lowest free 3.05-3.13 GB against 1.0-1.4 GB; 4 MiB
  allocations in memory 47 MB against 1.8 GB. Write-watch askings 11-39 ms a frame against 5-9
  (reads through the kernel in the taking made them 40-190: moved into the refresh). The CPU side
  is a reservation, committed only if shaders are ever declared to write the window (none so far).
- Belobug#443's xmem change (pages already showing what is asked are not mapped again,
  `VICTORY_MAP_SAME=0` as before) and #413 (zero only what no run covers) taken.

## Done (session 1)

- **avatarmanz main merged** (6d0ae9c1, 77 commits): renderer ports 5-7, their
  wave32 work (28 programs left without a wave32 lowering), their switch-guarded
  cool_fox ports (play.ps1 turns on the ones measured here: VICTORY_RESIDENCY,
  VICTORY_FALLBACK_HEAPS, VICTORY_SWEEP_PER_HEAP, VICTORY_XMA_REFILL). Our
  movie-plane uploads (they did not take them) kept on their texture.rs.
- **Committed page pool** (911a57f9, `VICTORY_POOL_COMMIT=1`, off by default): the
  title's 6.1 GiB pool made SEC_COMMIT, so view memory that is one run of the
  section can be placed in place through the section
  (`OpenExistingHeapFromFileMapping`, any Windows 10+), and **renderer port 1
  works without ID3D12Device13** (the 185 MB constants heap in place on this
  Windows 11 21H2).

- **Windows 10 / 11 branch for title memory in place** (`inplace.rs`): the Windows
  build is read from the registry and logged; how memory is opened is decided by
  what the D3D12 runtime has (`Part` with `ID3D12Device13`, `Region` with only
  `ID3D12Device3` = Windows 10 and Windows 11 21H2, else copies). GPU test on the
  software adapter: `warp_windows_of_one_allocation_in_place_without_device13`.

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

0. **Commit leaked by the NVIDIA driver for sections opened as heaps (2026-11-26, found and
   gated).** After a day of runs ~50 GB of the PC's commit stayed in use with no game
   running; the run `s-bigtrace-1126-130747` died on a failed allocation, the screen
   flashed, and the system-managed pagefile grew to 54 GB (C: at 74 MB free). A reboot gave
   it back. The test `inplace::tests::card_section_heap_after_the_process` (ignored; a 1 GiB
   `SEC_COMMIT` section on the RTX 3060, `VICTORY_LEAK_END=clean|exit|abort|region|none`,
   system commit read with GetPerformanceInfo before and after) showed: opened as a heap with
   `OpenExistingHeapFromFileMapping`, **0.7-0.95 GB of each GiB stays committed after the
   process, whether it let everything go, exited or aborted**; the section alone (`none`)
   and a committed allocation opened whole with `OpenExistingHeapFromAddress` (`region`, what
   `VICTORY_INPLACE=1` uses for title buffers) leave nothing. Each run with the committed page
   pool so left ~5-6 GB until the PC restarts. **Done:** `inplace::sections_allowed`: a
   section is opened as a heap only with `VICTORY_INPLACE_SECTIONS=1` (warns), whatever
   `VICTORY_POOL_COMMIT` says; play.ps1 no longer sets `VICTORY_POOL_COMMIT`. In-place view
   memory (exact windows, the renderer port's regions) therefore falls back to copies.
   Checked with a game run (`s-noleak`, Series S, 10 scene lines): system commit after the
   run 258 MB lower than before it; 4.2 fps median (239 ms), as before; peak private
   18.7 GB (16.7 GB with section heaps: view memory is copied again), 224 MB free at the low.
   **Next:** a way to read view memory in place without a section heap (e.g. map the pool's
   views from a committed allocation opened whole), and the cost of losing it (fps, memory).
   Device13's `OpenExistingHeapFromAddress1` is untested (not on build 22000).
   Tried (2026-11-26): a file-backed section (`VICTORY_LEAK_END=file`, a temporary file on
   E:) is refused by `OpenExistingHeapFromFileMapping`: not a way around the leak. Ideas left:
   exact-size copies instead of 4 MiB cells for view memory (the 2 GB is window copies);
   only pagefile sections open as heaps, so in place needs another opening.

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
   watching and copying) now opens memory on every Windows: `inplace::opening`
   picks `Part` (`ID3D12Device13`, recent Windows 11) or `Region` (`ID3D12Device3`:
   Windows 10, and Windows 11 21H2 like this PC, which lacks Device13): the whole
   allocation opened once and windows placed in it (`VICTORY_INPLACE_OPEN`,
   `VICTORY_INPLACE_REGION_MB`). **But it saves nothing here**: the copied windows
   (2.8-3 GB) are view memory (the title's page pool, sections), which stage 1 does
   not open on any Windows; only a couple of private windows qualify. What would:
   avatarmanz's renderer ports (the title's graphics heap in place). At a run's start only ~8 GB is free (Windows
   and other apps hold the rest); the game reaches 19 GB private even on Series S,
   so frames swing 0.2-1.8 s with paging and run-to-run comparisons are noisy.
3. **CPU: preparing 140-350 ms a frame**, of it copies 40-120 ms (~100 MB),
   refreshes ~130 ms (4,346 of 5,302 known to copy nothing), copy-back 60-100 ms.
4. **Pair meetings hang the card** (opt-in now): re-test 1004's uniform wait with
   `VICTORY_PAIR_MEET=1` on Series S, short run, before turning on.
5. **71 mesh shaders (ped skinning) fail DXIL validation**: vertex + primitive
   output > 32 KiB.
6. Wave64 leftovers without pair meetings: 23 64-thread compute programs dropped
   ("no wave32 lowering"), the builder's 9.

## Memory (Series S cutscene, `VICTORY_MEMORY_CATEGORIES=1`, overlapping)

Who owns our two largest heap blocks (`VICTORY_BIG_TRACE=1` logs the call stack of each block
of 32 MB or more): the 251.63 MB one is the title's audio processor heap
(`audio::ApuAlloc` -> `heap_alloc`), the 82.06 MB one title memory for a committed resource
(`xmem::XMemAllocDefault` via `resource::Memory::for_resource`). Both are the title's asks,
not ours. Of the rest: 19,126 shader containers (189 MB) are kept, of which only 2,349 are
ever translated.

Private ~18.6 GB on a 24 GB PC: title window copies 3.8 GB (in PC memory; the
GPU reads them over PCIe anyway), command-list growth 2.8-3.3 GB, our Rust heap
1.5 GB, texture copies ~3.5 GB **in VRAM** (pool heaps are DEFAULT: not RAM). The
title's own share is roughly 6-7 GB. Of ~800 windows a frame, only ~19 (88 MB)
are one run of the pool: the rest are scattered over several views and still
copied. Command lists: `VICTORY_LIST_LAZY=1` (34015389) leaves a submitted list without a host
list until its reset, and the idle pool lets go of lists idle > 5 s beyond 64: 1,349 ->
~900 alive, ~0.5-0.75 GB. What is left is lists recording or in flight at once, each two
allocators that keep the most they ever recorded. Next there: let go of a list whose
allocators grew past a size instead of pooling it; share preludes.
Windows: the copied ones were 4 MiB grid cells over streaming memory the title maps 64 KiB
page by page (517 of 548 cells "with holes", 31 scattered), while what an ask names is nearly
always one run of the pool. `VICTORY_WINDOW_EXACT=1` places just the asked range (64 KiB lines)
in place first. Asks with no length (root views: the shader reads from the address up to the cell's end)
are placed in place up to the end of their run of the pool when that run ends at a hole
(unmapped page: a stream does not reach over one; a copy holds zeros there too) or at the
cell's end; where a page mapped from elsewhere follows, the stream may go on and the copy
stays (`inplace::tail_run`). The draw cannot give a length (mesh shaders read their own
vertex counts). 479 no-length windows in place (was 114), copies without a length 1.38 GB
(was 1.64), window copies 2.51 GB (was 2.88), ~0.2-0.4 GB less private; frames intact.
Truly scattered windows: ~30, ~130 MB.
Targets: (1) scattered windows (a placed buffer per run, or the
64 KiB-directory addressing the ray-tracing path uses), (2) command-list growth,
(3) the Rust heap.

## Plans (in order)

1. Split the 2.8 -> 4.1 fps gain between the merge and the committed pool (A/B run
   without `VICTORY_POOL_COMMIT`); if the pool holds, make it the default in play.ps1.
2. Merge avatarmanz's 77 new commits (renderer ports 5-7: ~22 fps on Series S
   there; port 6 moves refresh planning and guard looks to helper threads; their
   own wave32 work; RAM-pressure caps). 61 conflict hunks in 16 files, mostly their
   switch-guarded ports of the same cool_fox commits we took: take theirs, turn on
   by default what was verified here (movie-plane uploads). Then fxceless's 8
   (card hashing -10 ms, flights -11.5 ms, texture checks on helpers -9 ms).
3. Memory first (it makes every other number noise here): find what of the 19 GB
   is ours and can go (host copies 3.6 GB, shared buffers 5 GB made, upload buffers
   3.1 GB made, lists' growth 2.7 GB, host textures 5.2 GB).
3. Guard pages for rarely written private memory (issue 1): the biggest CPU cost.
4. Refresh overhead for refreshes known to copy nothing (issue 3).
5. Re-test pair meetings (1004's uniform wait), short Series S run; then the builder
   (`-RayTracing`).

## Unattended runs

Runs since the avatarmanz merge ended at 77-103 s with `window closed` in the log:
that line is written only for a user close (close button, Alt+F4, taskbar or window
menu: `WM_SYSCOMMAND SC_CLOSE`), not by the runtime. It was the user closing it while
watching (confirmed); not a fault. Leave the window open during a run: the harness
stops the title itself.

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
| 2026-11-26 | 1005, Series S | opening cutscene | stable; median 336 ms (3.0 fps), best 206; preparing median 240 ms; 19.0 GB private, 22 MB free at worst |
| 2026-11-26 | 1005, Series S, `VICTORY_INPLACE=1` | opening cutscene | in place refused (no ID3D12Device13 on build 22000); median 758 ms, paging (15 MB free) |
| 2026-11-26 | 1005 + Region path, Series S, `VICTORY_INPLACE=1` | opening cutscene | opening=Region chosen; 0 windows in place (view memory); median 347 ms (2.9 fps), 19.3 GB private |
| 2026-11-26 | 1006 merge, Series S, ports 1,2,5,6,7 | opening cutscene | median 362 ms (2.8 fps); port 1 and 5 nothing (no Device13) |
| 2026-11-26 | + `VICTORY_POOL_COMMIT=1 VICTORY_INPLACE=1` | opening cutscene | **median 245 ms (4.1 fps), best 136 ms (7.3)**; 19 windows in place; 19.3 GB |
| 2026-11-26 | + port 1 through the section | opening cutscene | median 244 ms (4.1 fps), best 202; port 1: 185 MB in place; watch 14-26 ms (was up to 1,170); 18.6 GB |
| 2026-11-26 | + no-length tails to a hole | opening cutscene, 5 lines (closed) | 4,830 windows (666 MB) in place; copies 2.51 GB; 16.68 GB at line 5 (was 16.9-17.1); 234 ms median (4.3 fps); geometry intact |
| 2026-11-26 | + `VICTORY_WINDOW_EXACT=1` (now default) | opening cutscene, 10 lines | 3,098 windows (350 MB) in place (was 20, 96 MB); window copies 2.9 GB (was 3.4-3.8); **~1 GB less private** at the same points (13.8-16.9 vs 14.9-17.9 GB); 240 ms median (4.2 fps), best 136; preparing 126 ms median; frames clean |
| 2026-11-26 | same, again (window closed at 78 s) | opening cutscene | host lists 764-861; 16.83 GB peak; 261 ms median. **This set is play.ps1's default now** (`-Safe` drops it) |
| 2026-11-26 | + `VICTORY_LIST_LAZY=1`, idle trimming | opening cutscene (short: window closed at 77 s) | host lists alive 853-977 (was 1,349); 0.5-0.75 GB less private at the same point; 254 ms median (noise) |
| 2026-11-26 | + Agility SDK 1.620.2, **unwarmed** (run `s-agility-1126-144950`) | opening cutscene | device13=true, opening=Part; library rejected, pipelines made in the scene: black, median 394 ms (2.5 fps), 18.3 GB peak; not a measure of Part |
| 2026-11-26 | + avatarmanz#377 #376 #391, Belobug#62 #32 (batch), A/B against d2e2d0b, Series S | opening cutscene | base 323 / 361 ms, batch **153** / 312 ms median (6.5 / 3.2 fps; the second batch run paged to 8 MB free); best 94 ms; preparing 82-240 ms; 18.9-19.1 GB, as before; no commit left behind |
| 2026-11-26 | batch, `VICTORY_WINDOWS_BAR_MB=4096 VICTORY_WINDOWS_BAR_PCT=97`, A B A B | opening cutscene | **`card memory the CPU maps supported=false`**: nothing moved (window copies 3.1 GB either way). Identical code ran 637 / 314 / 168 / 232 ms median: frame rate follows free RAM at worst (47 MB -> 1.6 fps, 1,104 MB -> 6.0 fps) |
| 2026-11-26 | + thin LTO, x86-64-v3 (Marvisak#3011), A B A B against the batch | opening cutscene | 164 / 465 ms without, 500 / 369 ms with: noise (lowest free 50-385 MB). Kept: standard settings, tests pass |
| 2026-11-26 | + Belobug#373 #374, `VICTORY_SEND_SPARE_MB=128 VICTORY_SCRATCH_SPARE_MB=32 VICTORY_READ_KEEP_MB=16 VICTORY_STAGING_IDLE_MS=10000`, A B A B | opening cutscene | peak **18.2-18.3 GB with, 18.5-18.8 without** (~0.4 GB); frames 425 / 1,676 ms with, 274 / 614 without (worse in both pairs); lowest free RAM no better. Left off (unset = as before) |
| 2026-11-26 | lean windows, A B A B (`x-lean3-*`) | opening cutscene | **5.7 / 4.7 fps lean, 5.1 / 4.2 without**; lowest free 3.1 GB against 1.0-1.4; peak private 18.7-19.4 GB both |
