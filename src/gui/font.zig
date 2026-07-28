//! A compact single-stroke vector font used for the OR120 panel lettering.
//!
//! Real Orange amps use clean all-caps silkscreen labels, so this font covers
//! A–Z, 0–9 and a few punctuation marks as polyline strokes on a unit cell
//! (x and y both run 0..1, y increasing downward to match screen space). Glyphs
//! are drawn with GL line strips, which keeps them crisp at any size without a
//! glyph atlas or external font file. Lowercase input is mapped to uppercase.

const std = @import("std");
const gl = @import("gl.zig");
const clay = @import("clay.zig");

const Point = [2]f32;
const Stroke = []const Point;
const Glyph = []const Stroke;

// Horizontal fraction of the em used by a glyph cell, and the extra tracking
// added after each glyph. `measure` and the panel layout must agree with these.
const glyph_width_ratio: f32 = 0.55;
const tracking_ratio: f32 = 0.14;
const space_ratio: f32 = 0.42;
const line_height_ratio: f32 = 1.2;

// --- Glyph outlines -------------------------------------------------------
// Each glyph is a list of open polylines. Curves are approximated by short
// straight segments, which reads as a tidy stencil at panel sizes.

const A = &[_]Stroke{ &.{ .{ 0, 1 }, .{ 0.5, 0 }, .{ 1, 1 } }, &.{ .{ 0.18, 0.62 }, .{ 0.82, 0.62 } } };
const B = &[_]Stroke{
    &.{ .{ 0, 0 }, .{ 0, 1 } },
    &.{ .{ 0, 0 }, .{ 0.7, 0 }, .{ 1, 0.12 }, .{ 1, 0.38 }, .{ 0.7, 0.5 }, .{ 0, 0.5 } },
    &.{ .{ 0, 0.5 }, .{ 0.75, 0.5 }, .{ 1, 0.62 }, .{ 1, 0.88 }, .{ 0.75, 1 }, .{ 0, 1 } },
};
const C = &[_]Stroke{&.{ .{ 1, 0.2 }, .{ 0.7, 0 }, .{ 0.3, 0 }, .{ 0, 0.25 }, .{ 0, 0.75 }, .{ 0.3, 1 }, .{ 0.7, 1 }, .{ 1, 0.8 } }};
const D = &[_]Stroke{
    &.{ .{ 0, 0 }, .{ 0, 1 } },
    &.{ .{ 0, 0 }, .{ 0.6, 0 }, .{ 1, 0.3 }, .{ 1, 0.7 }, .{ 0.6, 1 }, .{ 0, 1 } },
};
const E = &[_]Stroke{ &.{ .{ 1, 0 }, .{ 0, 0 }, .{ 0, 1 }, .{ 1, 1 } }, &.{ .{ 0, 0.5 }, .{ 0.8, 0.5 } } };
const F = &[_]Stroke{ &.{ .{ 1, 0 }, .{ 0, 0 }, .{ 0, 1 } }, &.{ .{ 0, 0.5 }, .{ 0.8, 0.5 } } };
const G = &[_]Stroke{&.{ .{ 1, 0.2 }, .{ 0.7, 0 }, .{ 0.3, 0 }, .{ 0, 0.25 }, .{ 0, 0.75 }, .{ 0.3, 1 }, .{ 0.7, 1 }, .{ 1, 0.75 }, .{ 1, 0.55 }, .{ 0.6, 0.55 } }};
const H = &[_]Stroke{ &.{ .{ 0, 0 }, .{ 0, 1 } }, &.{ .{ 1, 0 }, .{ 1, 1 } }, &.{ .{ 0, 0.5 }, .{ 1, 0.5 } } };
const I = &[_]Stroke{ &.{ .{ 0.5, 0 }, .{ 0.5, 1 } }, &.{ .{ 0.25, 0 }, .{ 0.75, 0 } }, &.{ .{ 0.25, 1 }, .{ 0.75, 1 } } };
const J = &[_]Stroke{&.{ .{ 1, 0 }, .{ 1, 0.78 }, .{ 0.7, 1 }, .{ 0.3, 1 }, .{ 0, 0.75 } }};
const K = &[_]Stroke{ &.{ .{ 0, 0 }, .{ 0, 1 } }, &.{ .{ 1, 0 }, .{ 0, 0.5 }, .{ 1, 1 } } };
const L = &[_]Stroke{&.{ .{ 0, 0 }, .{ 0, 1 }, .{ 1, 1 } }};
const M = &[_]Stroke{&.{ .{ 0, 1 }, .{ 0, 0 }, .{ 0.5, 0.55 }, .{ 1, 0 }, .{ 1, 1 } }};
const N = &[_]Stroke{&.{ .{ 0, 1 }, .{ 0, 0 }, .{ 1, 1 }, .{ 1, 0 } }};
const O = &[_]Stroke{&.{ .{ 0.3, 0 }, .{ 0.7, 0 }, .{ 1, 0.25 }, .{ 1, 0.75 }, .{ 0.7, 1 }, .{ 0.3, 1 }, .{ 0, 0.75 }, .{ 0, 0.25 }, .{ 0.3, 0 } }};
const P = &[_]Stroke{&.{ .{ 0, 1 }, .{ 0, 0 }, .{ 0.7, 0 }, .{ 1, 0.25 }, .{ 0.7, 0.5 }, .{ 0, 0.5 } }};
const Q = &[_]Stroke{
    &.{ .{ 0.3, 0 }, .{ 0.7, 0 }, .{ 1, 0.25 }, .{ 1, 0.75 }, .{ 0.7, 1 }, .{ 0.3, 1 }, .{ 0, 0.75 }, .{ 0, 0.25 }, .{ 0.3, 0 } },
    &.{ .{ 0.6, 0.7 }, .{ 1, 1 } },
};
const R = &[_]Stroke{
    &.{ .{ 0, 1 }, .{ 0, 0 }, .{ 0.7, 0 }, .{ 1, 0.25 }, .{ 0.7, 0.5 }, .{ 0, 0.5 } },
    &.{ .{ 0.5, 0.5 }, .{ 1, 1 } },
};
const S = &[_]Stroke{&.{ .{ 1, 0.2 }, .{ 0.7, 0 }, .{ 0.3, 0 }, .{ 0, 0.2 }, .{ 0.3, 0.5 }, .{ 0.7, 0.5 }, .{ 1, 0.75 }, .{ 0.7, 1 }, .{ 0.3, 1 }, .{ 0, 0.8 } }};
const T = &[_]Stroke{ &.{ .{ 0, 0 }, .{ 1, 0 } }, &.{ .{ 0.5, 0 }, .{ 0.5, 1 } } };
const U = &[_]Stroke{&.{ .{ 0, 0 }, .{ 0, 0.75 }, .{ 0.3, 1 }, .{ 0.7, 1 }, .{ 1, 0.75 }, .{ 1, 0 } }};
const V = &[_]Stroke{&.{ .{ 0, 0 }, .{ 0.5, 1 }, .{ 1, 0 } }};
const W = &[_]Stroke{&.{ .{ 0, 0 }, .{ 0.25, 1 }, .{ 0.5, 0.5 }, .{ 0.75, 1 }, .{ 1, 0 } }};
const X = &[_]Stroke{ &.{ .{ 0, 0 }, .{ 1, 1 } }, &.{ .{ 1, 0 }, .{ 0, 1 } } };
const Y = &[_]Stroke{ &.{ .{ 0, 0 }, .{ 0.5, 0.5 }, .{ 1, 0 } }, &.{ .{ 0.5, 0.5 }, .{ 0.5, 1 } } };
const Z = &[_]Stroke{&.{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 } }};

const N0 = &[_]Stroke{ O[0], &.{ .{ 0.25, 0.85 }, .{ 0.75, 0.15 } } };
const N1 = &[_]Stroke{ &.{ .{ 0.28, 0.2 }, .{ 0.5, 0 }, .{ 0.5, 1 } }, &.{ .{ 0.25, 1 }, .{ 0.75, 1 } } };
const N2 = &[_]Stroke{&.{ .{ 0, 0.25 }, .{ 0.3, 0 }, .{ 0.7, 0 }, .{ 1, 0.25 }, .{ 0, 1 }, .{ 1, 1 } }};
const N3 = &[_]Stroke{&.{ .{ 0, 0.2 }, .{ 0.3, 0 }, .{ 0.7, 0 }, .{ 1, 0.25 }, .{ 0.5, 0.5 }, .{ 1, 0.75 }, .{ 0.7, 1 }, .{ 0.3, 1 }, .{ 0, 0.8 } }};
const N4 = &[_]Stroke{ &.{ .{ 0.7, 1 }, .{ 0.7, 0 } }, &.{ .{ 0.7, 0 }, .{ 0, 0.6 }, .{ 1, 0.6 } } };
const N5 = &[_]Stroke{&.{ .{ 1, 0 }, .{ 0, 0 }, .{ 0, 0.5 }, .{ 0.7, 0.5 }, .{ 1, 0.7 }, .{ 0.7, 1 }, .{ 0.2, 1 }, .{ 0, 0.85 } }};
const N6 = &[_]Stroke{&.{ .{ 1, 0.2 }, .{ 0.6, 0 }, .{ 0.25, 0.15 }, .{ 0, 0.6 }, .{ 0.15, 0.9 }, .{ 0.5, 1 }, .{ 0.8, 0.9 }, .{ 1, 0.7 }, .{ 0.8, 0.5 }, .{ 0.3, 0.48 }, .{ 0.05, 0.62 } }};
const N7 = &[_]Stroke{&.{ .{ 0, 0 }, .{ 1, 0 }, .{ 0.4, 1 } }};
const N8 = &[_]Stroke{&.{ .{ 0.5, 0 }, .{ 0.2, 0.08 }, .{ 0.15, 0.25 }, .{ 0.4, 0.45 }, .{ 0.75, 0.55 }, .{ 0.9, 0.78 }, .{ 0.7, 1 }, .{ 0.3, 1 }, .{ 0.1, 0.78 }, .{ 0.25, 0.55 }, .{ 0.6, 0.45 }, .{ 0.85, 0.25 }, .{ 0.8, 0.08 }, .{ 0.5, 0 } }};
const N9 = &[_]Stroke{&.{ .{ 0, 0.8 }, .{ 0.4, 1 }, .{ 0.75, 0.85 }, .{ 1, 0.4 }, .{ 0.85, 0.1 }, .{ 0.5, 0 }, .{ 0.2, 0.1 }, .{ 0, 0.3 }, .{ 0.2, 0.5 }, .{ 0.7, 0.52 }, .{ 0.95, 0.38 } }};

const DASH = &[_]Stroke{&.{ .{ 0.15, 0.5 }, .{ 0.85, 0.5 } }};
const DOT = &[_]Stroke{&.{ .{ 0.45, 0.92 }, .{ 0.55, 0.92 }, .{ 0.55, 1 }, .{ 0.45, 1 }, .{ 0.45, 0.92 } }};
const SLASH = &[_]Stroke{&.{ .{ 1, 0 }, .{ 0, 1 } }};

fn glyphFor(ch: u8) ?Glyph {
    return switch (ch) {
        'A', 'a' => A,
        'B', 'b' => B,
        'C', 'c' => C,
        'D', 'd' => D,
        'E', 'e' => E,
        'F', 'f' => F,
        'G', 'g' => G,
        'H', 'h' => H,
        'I', 'i' => I,
        'J', 'j' => J,
        'K', 'k' => K,
        'L', 'l' => L,
        'M', 'm' => M,
        'N', 'n' => N,
        'O', 'o' => O,
        'P', 'p' => P,
        'Q', 'q' => Q,
        'R', 'r' => R,
        'S', 's' => S,
        'T', 't' => T,
        'U', 'u' => U,
        'V', 'v' => V,
        'W', 'w' => W,
        'X', 'x' => X,
        'Y', 'y' => Y,
        'Z', 'z' => Z,
        '0' => N0,
        '1' => N1,
        '2' => N2,
        '3' => N3,
        '4' => N4,
        '5' => N5,
        '6' => N6,
        '7' => N7,
        '8' => N8,
        '9' => N9,
        '-' => DASH,
        '.' => DOT,
        '/' => SLASH,
        else => null, // space and unknowns advance without ink.
    };
}

/// Advance width (in pixels) of one glyph cell at `font_size`.
fn advance(font_size: f32) f32 {
    return font_size * (glyph_width_ratio + tracking_ratio);
}

/// Total rendered size of `s` at `font_size`, matching Clay's measure contract.
pub fn measure(s: []const u8, font_size: f32) clay.Dimensions {
    var width: f32 = 0;
    for (s) |ch| {
        width += if (ch == ' ') font_size * space_ratio else advance(font_size);
    }
    return .{ .width = width, .height = font_size * line_height_ratio };
}

/// Draw `s` with its top-left at (x, y). Colour must already be bound; the
/// caller manages GL blend state. Glyphs are centred vertically inside the
/// line-height box so text sits nicely against Clay's layout boxes.
pub fn draw(s: []const u8, x: f32, y: f32, font_size: f32) void {
    const cell_w = font_size * glyph_width_ratio;
    const cell_h = font_size;
    const top = y + (font_size * line_height_ratio - cell_h) * 0.5;

    var pen_x = x;
    for (s) |ch| {
        if (ch == ' ') {
            pen_x += font_size * space_ratio;
            continue;
        }
        if (glyphFor(ch)) |glyph| {
            for (glyph) |stroke| {
                gl.glBegin(gl.GL_LINE_STRIP);
                for (stroke) |p| {
                    gl.glVertex2f(pen_x + p[0] * cell_w, top + p[1] * cell_h);
                }
                gl.glEnd();
            }
        }
        pen_x += advance(font_size);
    }
}
