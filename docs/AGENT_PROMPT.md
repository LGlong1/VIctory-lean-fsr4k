# Base prompt for agents working on VIctory-NV

Read this first, then `docs/STATUS.md`, then pick up the first open plan there.

## What this is

A fork of the VIctory static recompiler (Rust, Direct3D 12): it runs the user's
own dump of the Xbox Series build of GTA VI natively on Windows. This fork
targets **NVIDIA** GPUs (32-lane waves, 1,000,000-view descriptor heaps, stricter
drivers than AMD's). Base: avatarmanz/VIctory-7900XTX, with work from fxceless,
Belobug, DexNom and our own. Machine: i5-11400F, 24 GB RAM, RTX 3060 12 GB.

## Rules

- **Nothing from the game is ever committed** or copied into a repository:
  no executables, archives, shaders, DXIL dumps, frames or logs with title data.
  `.gitignore` and `cargo xtask policy` (pre-commit hook) enforce it; never
  bypass them. Game files live in `E:\Games\GTA6.Xbox.v1.0.2.1`, our data in
  `E:\Dev\victory-data`.
- Never run binaries from other forks or downloads. Read their source; build it
  ourselves if needed.
- Other forks' work comes in commit by commit, each read against what this tree
  already does: taken / ours kept / own fix / measure first / skip, recorded in a
  `docs/*-merge-decisions.md`.
- Every new behaviour gets a `VICTORY_*` switch to turn it off, documented where
  it is read, and a test where it can have one (GPU tests run on the 3060).
- Commit messages say what changed and why, in the repo's style (plain
  sentences, the measured numbers), ending with the co-author line in use.
- **Update `docs/STATUS.md`** whenever something changes: a fix, a measurement,
  a new issue, a changed plan. Keep it short and current.

## Layout and commands

- Work in `E:\Dev\VIctory-merge` (branch `merge/fxceless`), then
  `git -C E:\Dev\VIctory-NV merge --ff-only merge/fxceless` to update `nvidia`.
- PowerShell: `$env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"` first.
- Build: `cargo build --locked --profile diag -p victory --features diagnostics`
  (a running `victory.exe` locks the binary: build when nothing runs).
- Translate all shaders into the cache after translator changes:
  `target\diag\victory.exe shaders <game>\shaders.rpf <game>\game_scarlett_master.exe <game>\XboxBvhBuilder.dll <game>\amd_fidelityfx_upscaler_xbox.dll`
- Pre-build pipelines (after a translator or driver change):
  `target\diag\victory.exe warm --used`
- Run: `scripts\play.ps1 -Exe <game>\game_scarlett_master.exe -More @{VICTORY_PIPELINE_BOOK='1'}`
  (`-RayTracing` for the BVH builder). Redirect `*>` to a log in `victory-data\logs`.
- Offline checks with the host's real limits:
  `VICTORY_HOST_WAVE=32 VICTORY_VIEW_LIMIT=999999 victory translate --list --validate [--pipelines]`
  (`--pipelines` asks the driver; `VICTORY_EMIT_DUMP=<dir>` writes DXIL;
  `VICTORY_WAVE_WHY=1` says why a program keeps 64-lane waves;
  `--warm <file of hashes>` translates just those).
- Tests: `cargo test --locked -p victory-shader --lib` (GPU tests included),
  `cargo test --locked -p victory-gpu --features diagnostics --lib -- <filter>`.
- Reading a run's log: frame lines `victory_gpu::host: N fps, M ms/frame ... draws/frame,
  dropped ... (being made)`; `host pipeline refused`; `WARN`/`ERROR` lines.

## Useful switches

`VICTORY_KEYS=<s>:<key>,...` scripted input (Enter, Esc, arrows, letters);
`VICTORY_CAPTURE=<dir>` writes presented frames as PNG (powers of two, plus
`VICTORY_CAPTURE_FRAMES`); `VICTORY_PIPELINE_BOOK=1` records pipelines for `warm`;
`VICTORY_D3D12_DRED=light|faults` crash data; F3 in game shows the stats panel.

## How to work

Measure, read the code, change the smallest thing that fixes the cause, test it
on the card, record the result in STATUS.md, commit. When a run is needed and
the user is away, use the unattended harness (`scripts\autotest.ps1`, see
STATUS.md) instead of waiting.
