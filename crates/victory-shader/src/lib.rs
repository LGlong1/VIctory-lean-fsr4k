//! Xbox Series shaders to host shaders.
//!
//! An Xbox Series shader is a standard DXBC container ([`dxbc`]). Its `DXIL`
//! part ([`dxil`]) may carry Xbox additions around the LLVM bitcode: an
//! `XDAT` table before it indexing blobs after it, among them `xbop`
//! (compiler options) and the zlib-compressed GFX10 code. The bitcode may use
//! console-only intrinsics, so the GFX10 code is translated in general.

pub mod bvh;
pub mod dxbc;
pub mod dxil;
pub mod emit;
pub mod gfx10;
pub mod io;
pub mod ir;
pub mod native;
pub mod resource;
pub mod spill;
pub mod structure;

/// The version of what the translator makes, part of the key of every
/// cached translation (`victory-gpu`'s `shader_cache`): **bump it with any
/// change that changes the translation of a shader** (its DXIL or what the
/// host binds for it). Changes that do not (speed, diagnostics, tests,
/// shaders that did not translate before) leave it, and every shader
/// translated before is kept across the rebuild. `victory shaders`
/// translates again what an earlier build of the translator cached and says
/// how many came out different: if any did, the bump was due.
///
/// The NVIDIA fork counts from 1001 so its versions never meet avatarmanz's
/// (1 there): 1001 is the pair meetings of console wave64 programs on 32-lane
/// hosts; 1002 adds cool_fox 8cc31ab's lane-uniform and restored-lane analysis; 1003
/// leaves 64-thread programs unwidened by default and waits at most 2^14 reads; 1004 keeps
/// a wave together in the wait (every lane decides on the first lane's read); 1005 makes pair
/// meetings opt-in (`VICTORY_PAIR_MEET=1`) after they hung the card; 1006 is the merge of
/// avatarmanz main (c9c932cb: their wave32 work, the fixed-point lane-uniform proof).
pub const TRANSLATOR_VERSION: u32 = 1006;

pub use dxbc::{Container, FourCC, Part};
pub use dxil::{DxilProgram, ShaderKind, XboxExtras};
pub use native::{
    HwStage, NativeProgram, ResourceType, RootParam, RootType, UsedResource, native_programs,
};

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum ShaderError {
    #[error("not a DXBC container")]
    NotDxbc,
    #[error("malformed shader: {0}")]
    Malformed(&'static str),
    #[error("GFX10 code at {offset:#x}: {reason}")]
    Isa { offset: usize, reason: &'static str },
    /// Valid code the translator cannot handle yet: an opcode name or a construct.
    #[error("GFX10 code at {offset:#x}: {what} is not supported")]
    Unsupported { offset: usize, what: &'static str },
}
