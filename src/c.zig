//! Central CLAP ABI access point.
//!
//! We use a hand-written pure-Zig binding (see clap_abi.zig) instead of
//! @cImport, because Zig's C translator mishandles CLAP's `#pragma once`
//! headers reached via `..` paths. The `clap` namespace name is preserved so
//! the rest of the codebase is agnostic to how the ABI is provided.
pub const clap = @import("clap_abi.zig");
