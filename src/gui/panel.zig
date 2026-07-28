//! OR120 front-panel layout, declared with Clay.
//!
//! Draws the orange tolex, picture-frame border, a black control strip and a
//! row of round knobs with cream pointers and silkscreen (stroke-font) labels.
//! Knob pointers rotate to reflect the current parameter value.

const std = @import("std");
const clay = @import("clay.zig");
const theme = @import("theme.zig");
const params = @import("../params.zig");
const cc = @import("../c.zig");
const c = clay.c;

fn open(decl: clay.ElementDeclaration) void {
    c.Clay__OpenElement();
    c.Clay__ConfigureOpenElement(decl);
}

fn close() void {
    c.Clay__CloseElement();
}

fn corner(r: f32) c.Clay_CornerRadius {
    return .{ .topLeft = r, .topRight = r, .bottomLeft = r, .bottomRight = r };
}

/// Stable Clay element id for the knob at `index`. Used both when declaring the
/// knob and when querying its bounding box for hit-testing.
pub fn knobId(index: usize) c.Clay_ElementId {
    return c.Clay_GetElementIdWithIndex(clay.str("OR120Knob"), @intCast(index));
}

fn labelText(s: []const u8) void {
    clay.text(s, std.mem.zeroInit(clay.TextElementConfig, .{
        .textColor = theme.label,
        .fontId = @as(u16, 0),
        .fontSize = @as(u16, 16),
    }));
}

/// Number of tick marks for the parameter at `index`: one per detent for
/// stepped controls, otherwise a fixed minor-tick count. Consumed by the GL
/// knob overlay in gui.zig.
pub fn tickCount(index: usize) usize {
    const d = params.descriptors[index];
    if ((d.flags & cc.clap.CLAP_PARAM_IS_STEPPED) != 0) {
        return @intFromFloat(d.max - d.min + 1.0);
    }
    return 11;
}

/// One labelled knob column. The knob body is an invisible, correctly sized
/// hit-target: its bounding box is cached by gui.zig and the actual knob (body,
/// cap, ticks and pointer) is drawn procedurally in the OpenGL overlay.
fn knobColumn(index: usize, name: []const u8) void {
    open(std.mem.zeroInit(clay.ElementDeclaration, .{
        .layout = .{
            .sizing = .{ .width = clay.sizingFixed(84), .height = clay.sizingGrow() },
            .padding = .{ .left = 6, .right = 6, .top = 6, .bottom = 6 },
            .childGap = 10,
            .layoutDirection = c.CLAY_TOP_TO_BOTTOM,
            .childAlignment = .{ .x = c.CLAY_ALIGN_X_CENTER, .y = c.CLAY_ALIGN_Y_CENTER },
        },
    }));
    {
        // Invisible knob body — carries the hit-test id and reserves the space
        // the GL overlay draws into.
        open(std.mem.zeroInit(clay.ElementDeclaration, .{
            .id = knobId(index),
            .layout = .{
                .sizing = .{ .width = clay.sizingFixed(64), .height = clay.sizingFixed(64) },
            },
            .backgroundColor = theme.transparent,
        }));
        close();
        // Label under the knob.
        labelText(name);
    }
    close();
}

/// Build the entire panel for this frame. Knob values are not needed here — the
/// knob visuals (including the pointer angle) are drawn by the GL overlay in
/// gui.zig from the cached bounding boxes and current parameter values.
pub fn build() void {
    // Root: orange tolex with a picture-frame border.
    open(std.mem.zeroInit(clay.ElementDeclaration, .{
        .layout = .{
            .sizing = .{ .width = clay.sizingGrow(), .height = clay.sizingGrow() },
            .padding = .{ .left = 18, .right = 18, .top = 18, .bottom = 18 },
            .childGap = 14,
            .layoutDirection = c.CLAY_TOP_TO_BOTTOM,
        },
        .backgroundColor = theme.transparent,
        .border = .{ .color = theme.tolex_dark, .width = .{ .left = 10, .right = 10, .top = 10, .bottom = 10, .betweenChildren = 0 } },
    }));
    {
        // Header row with the brand lettering.
        open(std.mem.zeroInit(clay.ElementDeclaration, .{
            .layout = .{
                .sizing = .{ .width = clay.sizingGrow(), .height = clay.sizingFixed(48) },
                .padding = .{ .left = 12, .right = 12, .top = 8, .bottom = 8 },
                .childAlignment = .{ .x = c.CLAY_ALIGN_X_LEFT, .y = c.CLAY_ALIGN_Y_CENTER },
            },
        }));
        {
            clay.text("ORANGE  OR120", std.mem.zeroInit(clay.TextElementConfig, .{
                .textColor = theme.cream,
                .fontId = @as(u16, 0),
                .fontSize = @as(u16, 28),
            }));
        }
        close();

        // Black control strip holding the knob row.
        open(std.mem.zeroInit(clay.ElementDeclaration, .{
            .layout = .{
                .sizing = .{ .width = clay.sizingGrow(), .height = clay.sizingGrow() },
                .padding = .{ .left = 16, .right = 16, .top = 16, .bottom = 16 },
                .childGap = 6,
                .layoutDirection = c.CLAY_LEFT_TO_RIGHT,
                .childAlignment = .{ .x = c.CLAY_ALIGN_X_CENTER, .y = c.CLAY_ALIGN_Y_CENTER },
            },
            .backgroundColor = theme.panel,
            .cornerRadius = corner(8),
            .border = .{ .color = theme.panel_edge, .width = .{ .left = 2, .right = 2, .top = 2, .bottom = 2, .betweenChildren = 0 } },
        }));
        {
            inline for (params.descriptors, 0..) |d, idx| {
                knobColumn(idx, d.name);
            }
        }
        close();
    }
    close();
}
