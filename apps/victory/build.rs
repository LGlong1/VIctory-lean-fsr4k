//! Exports the D3D12 Agility SDK's two values from `victory.exe` (see
//! `src/agility.rs`): `d3d12.dll` looks them up in the executable by name.

fn main() {
    let target = std::env::var("CARGO_CFG_TARGET_ENV").unwrap_or_default();
    let os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if os == "windows" && target == "msvc" {
        println!("cargo:rustc-link-arg-bins=/EXPORT:D3D12SDKVersion,DATA");
        println!("cargo:rustc-link-arg-bins=/EXPORT:D3D12SDKPath,DATA");
    }
    println!("cargo:rerun-if-changed=build.rs");
}
