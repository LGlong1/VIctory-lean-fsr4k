# fxceless/victory-fork → nvidia: what came over and why

fxceless/victory-fork (RTX 4070, 7–12 fps, played past the first boat mission) had
82 commits on 2026-11-25/26 that this tree (avatarmanz/VIctory-7900XTX + Belobug)
lacks. A plain merge conflicted in 25 files (~255 hunks, ~13,000 lines), mostly
`host.rs`, `shadow.rs`, `indirect.rs`, `watch.rs`: the two forks solved the same
CPU bottleneck (one thread preparing submissions) with **different designs**
(fxceless: own submit thread, fetch copy queue, card-side hashing;
this tree: `VICTORY_THIN`, relay/land, async submit). Those conflicts are two
architectures, not two edits, so the merge was done **commit by commit**, each
one read against what this tree already does.

Decisions: **taken** (as is or with conflicts resolved), **ours kept** (this
tree already does it, often more completely), **own fix** (the idea is right,
written for this tree), **measure first** (performance design; decided by an
A/B run on the RTX 3060), **later**, **skip**.

## Taken

| Commit | What | Notes |
|---|---|---|
| 41f9857 | A view moved to the first level with memory keeps the title's minimum level | Clean. |
| 19a45d1 | A view of a texture the card wrote is copied from it even after an upload of the same view from title memory | Our `texture::alias` had the same bug (first use in a list taken as "copy owed"). Conflict was two methods side by side; `Deferred` is reset wholesale so the new map clears with it. |
| a35c557 | A draw into a render target of another format than its pipeline declares gets a pipeline for the bound format (`VICTORY_TARGET_VARIANTS=0`: off) | Invalid call on the host, undefined on NVIDIA; fxceless saw it during a full-screen zoom/blur effect (our intro "zooms"). Resolved onto **our** blend design: we keep the title's blend state and apply `host_blend()` at pipeline creation, so their `blend_as_given` / `integer_targets_do_not_blend` rework was dropped and the variant gets correct blending for free. Format capture placed inside our `set_targets` bind cache, recorded **before** its early return. Their tests adapted to `host_blend`. |
| f9fdf19 | Removal report says DRED's own class: hung / fault / page fault | Their hunk sat on helpers we lack; the DRED2 query was placed at the top of our `removal_data`. |

## Own fix

| Commit | Idea | What we did instead |
|---|---|---|
| 6a42ed2 | An older save version that cannot be removed (antivirus, backup) must not fail the container | Kept **our** `current()` (it also survives an unreadable newer manifest, theirs does not) and made its two `remove_dir_all(..)?` non-fatal. Their test kept. |
| b9011c9 | Memory at the moment of a device removal; Present's error not thrown away | Theirs builds on removal infrastructure we do not have. Ours: `log_removal_context` always says process private/peak, system commit vs limit, free RAM, then the card's budget via the existing `log_video_memory`; Present's first error said once. |

## Ours kept (equivalent or better already here)

| Commit | Why |
|---|---|
| 2ba6e1f, a183ea2, 619b2dc | Constant views capped at 64 KiB (NVIDIA removes the device for more). Our `constant_bytes()` already caps **before** rounding and keeps 0 as 0, which is where fxceless ended after two follow-ups. |
| 025b042 | Integer render targets do not blend. Our `host_blend()` already does it (found via vkd3d-proton refusing the pipeline). |
| 32be36d (+ bc6ee68) | Per-thread cache of buffer lookups (~14 ms/frame on their 4070). Ours: `VICTORY_QUICK_FIND` (on by default) plus an RwLock read path on the buffer table. **Gap:** ours does not cache lookups that go through windows (`loose`). Extend ours if the 3060 profile shows `loose` hot. |
| 895c0b8, 04df435 | Water texture read-back (boats float): `VICTORY_TEXTURE_BACK` is already here. |
| 4cc775f | DRED light/faults forms: already here. |

## Measure first (performance design: decided by the A/B on the RTX 3060)

The fxceless build is in `E:\Dev\VIctory-fxceless` (detached at fxceless/main) for
the side-by-side run. If its submission path beats ours on this 6-core CPU, the
pieces below come over **one at a time, each measured**; if not, they stay out.

- Submission / CPU side: 9376fd6, f85101b, 0b0074e, 3973179, 84c5dc0, de4146a,
  6aed078, 895a23b, 5d659e0, d4a528b, 4d0c634, 006c353 (+ 36bdd51)
- Card side: 5557224 + 6d20eed (card hash over 64 threads, made opt-in after
  problems), c36971b (small buffers on the card), 465b94f (indirect gather,
  10.3 fps in their first rooms), 94ed363 (lock-free refresh)
- 0fc6b06: measured at nothing by fxceless themselves → skip unless the A/B says otherwise

## Later

- 96ff135 (`VICTORY_BVH_NO_HIT`, `VICTORY_WAVE_WIDE=last`): ray tracing and
  wave64 on 32-lane hosts. Revisit at the NVIDIA ray-tracing step.
- On-screen fps / load box (ca8829f, 2095f15): wanted for recorded evidence
  (PortWatch scores from video). Port as one piece when we record.
- Frame shots and instruments (79cfdd9, 249f2c2, 7496a4c, a253706's frame log,
  ca8ce8a, 0672327, da4f249, ac25549, bbf8de9, f38b427, 4679615, d8986cd):
  this tree has `replay` and its own lines; take one only when a question needs it.

## Skip

- d03859a, 44bff61: fix/extend `VICTORY_ABSENT_ONCE`, which this tree does not have.
- 97f8dbc, 0c7807a, 9686ea3, 89e4127: their CI and tests on machines without a card.
- 27 commits that touch only README, docs or `diagnostics/` run logs.
