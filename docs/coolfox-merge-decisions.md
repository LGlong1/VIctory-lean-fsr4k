# CGBJ cool_fox → nvidia: what came over and why

Source: codec-d/cool_fox (GPL-3.0), the build PortWatch verified at ~25 fps on
NVIDIA with 8 GB of system RAM. The GitHub repository returned 404 on
2026-11-26; it was read from a mirror (git.gtahub.st/github/codec-d--cool_fox).
**Provenance:** its history below `0a435665` is avatarmanz/VIctory-7900XTX's,
hash for hash; the 6 commits on top are codec_d's, as the mirror holds them
(a mirror could alter those; they were read whole before anything was taken).
Scanned for network, process, download and deletion code: none in the Rust
changes; the only hits are a launcher `.cmd` for their prebuilt binary and a
README link to private releases (neither taken).

cool_fox is avatarmanz's fork at 0a435665 plus these commits; ours already
holds everything up to afe6ea1 of avatarmanz.

| Commit | What | Decision |
|---|---|---|
| e05d463 | Two-plane compose (Series S presents scene + interface as two planes), fallback heaps, `TablePlan` (each shader's table layout worked out once, not per draw), a residency guard, 256 MiB DirectStorage staging floor (`VICTORY_DSTORAGE_STAGING_MB`), **blocking fence waits** (`SetEventOnCompletion` with no event was "not implemented": now `WaitOnAddress`, woken by the fence's signal), scripted keys in release builds | **Taken** (applied clean). TablePlan and the fence wait are CPU savings. |
| 1ad6e67 | Series S two-plane black screen: the retail plane read at its 72-byte stride | **Taken** (clean). Needed for the Series S profile. |
| 8cc31ab | NVIDIA wave32 lowering; **movie-plane uploads** (a dedicated upload buffer per list for the video decoder's CPU-written planes, so frames in flight never overwrite each other: the likely fix of our rewinding intro); XMA audio fixes; residency budgets; `left_out` (no ~1,000 `CS_RaytracingResolve` pipelines compiled when the BVH builder is off); `scene_input` (first-scene pipelines made early on a cold cache) | **Taken with conflicts resolved.** Wave32: **ours kept** as the default (pair meetings cover groups of several console waves: builder 52/52, title 28/29; theirs widens two kernels named by digest and one loop shape); their `driver_loop` kept as the fallback when pair meetings are off; their lane-uniform and restored-lane analysis taken (translator version 1002). `texture.rs`: their `record_upload` (it holds our pool aliasing barrier, through our `barriers` wrapper). `place.rs`: their `Step::Plane` read added to our counted match. `make.rs`: both sides' fields. |
| 18bdf79 | Bindless refreshes scoped to their heap; speculative staging bounded | **Taken** (clean after 8cc31ab). |
| ab75ac3 | Refused GPU pool growth backs off; uploads deferred while commit is low | **Taken** (clean after 8cc31ab). Fits a 24 GB PC near its commit limit. |
| f4b48ad | "Publish the pareto-residency Windows build and portable launcher" | **Skipped**: a prebuilt-binary launcher and README pointing at private releases. Its launcher shows the profile they run: `--console series-s` (to be measured here). |

Residency budgets are adaptive (limited RAM = 32 GB or less; pressure when
free physical memory < 4-6 GB or free commit < 6-8 GB), not tuned to 32 GB.
