//! Zig binding + thin ergonomic wrapper around the Clay layout library.
//!
//! Clay's public API is macro-based (the `CLAY(){ ... }` block syntax), which
//! does not survive `@cImport`. We therefore call the underlying internal
//! functions (`Clay__OpenElement` / `Clay__ConfigureOpenElement` /
//! `Clay__CloseElement`) directly and provide small helpers so the layout code
//! in `panel.zig` stays readable.

const std = @import("std");

pub const c = @cImport({
    @cInclude("clay.h");
});

// Re-export the commonly used Clay types under short names.
pub const Color = c.Clay_Color;
pub const Dimensions = c.Clay_Dimensions;
pub const Vector2 = c.Clay_Vector2;
pub const String = c.Clay_String;
pub const ElementDeclaration = c.Clay_ElementDeclaration;
pub const TextElementConfig = c.Clay_TextElementConfig;
pub const RenderCommandArray = c.Clay_RenderCommandArray;
pub const RenderCommand = c.Clay_RenderCommand;
pub const BoundingBox = c.Clay_BoundingBox;

/// Build a `Clay_String` from a Zig slice (not necessarily null-terminated).
pub fn str(s: []const u8) String {
    return .{
        .isStaticallyAllocated = true,
        .length = @intCast(s.len),
        .chars = s.ptr,
    };
}

/// Open an element, configure it with `decl`, run `body`, then close it. This
/// mirrors the `CLAY({...}){ body }` block form.
pub inline fn element(decl: ElementDeclaration, ctx: anytype, comptime body: fn (@TypeOf(ctx)) void) void {
    c.Clay__OpenElement();
    c.Clay__ConfigureOpenElement(decl);
    body(ctx);
    c.Clay__CloseElement();
}

/// Declare a leaf element (no children).
pub inline fn box(decl: ElementDeclaration) void {
    c.Clay__OpenElement();
    c.Clay__ConfigureOpenElement(decl);
    c.Clay__CloseElement();
}

/// Emit a text element.
pub inline fn text(s: []const u8, config: TextElementConfig) void {
    c.Clay__OpenTextElement(str(s), c.Clay__StoreTextElementConfig(config));
}

// --- Sizing helpers -------------------------------------------------------

pub fn sizingFixed(px: f32) c.Clay_SizingAxis {
    var axis: c.Clay_SizingAxis = std.mem.zeroes(c.Clay_SizingAxis);
    axis.type = c.CLAY__SIZING_TYPE_FIXED;
    axis.size.minMax = .{ .min = px, .max = px };
    return axis;
}

pub fn sizingGrow() c.Clay_SizingAxis {
    var axis: c.Clay_SizingAxis = std.mem.zeroes(c.Clay_SizingAxis);
    axis.type = c.CLAY__SIZING_TYPE_GROW;
    return axis;
}

pub fn sizingPercent(p: f32) c.Clay_SizingAxis {
    var axis: c.Clay_SizingAxis = std.mem.zeroes(c.Clay_SizingAxis);
    axis.type = c.CLAY__SIZING_TYPE_PERCENT;
    axis.size.percent = p;
    return axis;
}

pub fn rgba(r: f32, g: f32, b: f32, a: f32) Color {
    return .{ .r = r, .g = g, .b = b, .a = a };
}
