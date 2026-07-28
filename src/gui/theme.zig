//! OR120 colour palette. Values are 0-255 RGBA to match Clay's convention.

const clay = @import("clay.zig");
const Color = clay.Color;

fn rgb(r: f32, g: f32, b: f32) Color {
    return .{ .r = r, .g = g, .b = b, .a = 255 };
}

/// Fully transparent — used where an element must not paint over the
/// procedural background.
pub const transparent = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };

/// Bright Orange-amp tolex.
pub const tolex = rgb(232, 104, 26);
/// Slightly darker orange for the picture-frame border.
pub const tolex_dark = rgb(196, 84, 16);
/// Near-black control panel face.
pub const panel = rgb(22, 19, 16);
/// Panel edge highlight.
pub const panel_edge = rgb(60, 52, 44);
/// Knob body.
pub const knob = rgb(34, 30, 26);
/// Raised knob cap (slightly lighter for relief).
pub const knob_cap = rgb(44, 39, 33);
/// Knob cap edge highlight.
pub const knob_edge = rgb(72, 63, 52);
/// Cream pointer / lettering.
pub const cream = rgb(236, 228, 210);
/// Muted label text.
pub const label = rgb(210, 200, 182);
