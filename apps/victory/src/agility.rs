//! The D3D12 Agility SDK: the runtime Microsoft ships with an application instead
//! of the one in Windows.
//!
//! Windows 11 21H2 (build 22000, the target PC) has no `ID3D12Device13` in its own
//! D3D12 runtime, and `ID3D12Device13::OpenExistingHeapFromAddress1` is what opens
//! a part of a committed allocation as a heap: the title's memory read in place
//! (`inplace::opening` picks `Part`), avatarmanz's renderer ports 1 and 5, without a
//! section heap (those leak commit on the NVIDIA driver, STATUS.md issue 0).
//!
//! `d3d12.dll` looks for these two exports in the executable when it is first
//! used: with them it loads `D3D12Core.dll` from `D3D12SDKPath` (relative to the
//! executable) if that folder holds a runtime of at least `D3D12SDKVersion`, and
//! otherwise goes on with the one in Windows. The DLLs are not in the repository
//! (Microsoft's, from the `Microsoft.Direct3D.D3D12` NuGet package):
//! `scripts\play.ps1` copies them into `target\<build>\D3D12\` from
//! `VICTORY_AGILITY_DIR` (default `E:\Dev\victory-data\agility\1.620.2`).
//!
//! **The switch is that folder**: without `D3D12\D3D12Core.dll` next to
//! `victory.exe` the runtime in Windows is used as before (`play.ps1 -NoAgility`
//! removes it). The log line `the device: ID3D12Device3 ..., ID3D12Device13 ...`
//! (`inplace.rs`) says which runtime was taken.
//!
//! The exports themselves are made by `build.rs` (`/EXPORT:...,DATA`).

/// The Agility SDK version the folder must hold at least (1.620.2).
#[unsafe(no_mangle)]
#[used]
#[allow(non_upper_case_globals)]
pub static D3D12SDKVersion: u32 = 620;

/// A C string pointer the runtime reads (`const char*`).
#[repr(transparent)]
pub struct SdkPath(*const u8);

// SAFETY: the pointer is to a 'static, immutable byte string; nothing writes it.
unsafe impl Sync for SdkPath {}

/// The folder of `D3D12Core.dll`, relative to the executable.
#[unsafe(no_mangle)]
#[used]
#[allow(non_upper_case_globals)]
pub static D3D12SDKPath: SdkPath = SdkPath(c".\\D3D12\\".as_ptr().cast());
