//! CLAP plugin entry point for the OR120 Amp Sim.
//!
//! Phase 1: a minimal, spec-compliant stereo audio-effect that loads in a host
//! and passes audio through the DSP engine (currently identity). Later phases
//! add parameters, state, and the Clay-based GUI.

const std = @import("std");
const c = @import("c.zig");
const dsp = @import("dsp/engine.zig");
const params = @import("params.zig");
const guimod = @import("gui/gui.zig");

const allocator = std.heap.c_allocator;

// ---------------------------------------------------------------------------
// Plugin descriptor
// ---------------------------------------------------------------------------

const plugin_id = "com.johan.or120ampsim";

const plugin_features = [_][*c]const u8{
    c.clap.CLAP_PLUGIN_FEATURE_AUDIO_EFFECT,
    c.clap.CLAP_PLUGIN_FEATURE_DISTORTION,
    c.clap.CLAP_PLUGIN_FEATURE_STEREO,
    null,
};

const descriptor = c.clap.clap_plugin_descriptor_t{
    .clap_version = .{
        .major = c.clap.CLAP_VERSION_MAJOR,
        .minor = c.clap.CLAP_VERSION_MINOR,
        .revision = c.clap.CLAP_VERSION_REVISION,
    },
    .id = plugin_id,
    .name = "OR120 Amp Sim",
    .vendor = "Johan",
    .url = "https://github.com/johan/OR120-Amp-Sim",
    .manual_url = "",
    .support_url = "",
    .version = "0.1.0",
    .description = "Orange OR120-inspired guitar amplifier simulation.",
    .features = &plugin_features,
};

// ---------------------------------------------------------------------------
// Plugin instance
// ---------------------------------------------------------------------------

const Plugin = struct {
    clap_plugin: c.clap.clap_plugin_t,
    host: [*c]const c.clap.clap_host_t,
    engine: dsp.Engine,
    params: params.State,
    changes: params.ChangeQueue = .{},
    gui: ?*guimod.Gui = null,

    fn fromClap(plugin: [*c]const c.clap.clap_plugin_t) *Plugin {
        return @ptrCast(@alignCast(plugin.*.plugin_data));
    }

    /// Apply any queued host parameter events to the atomic store.
    fn applyInputEvents(self: *Plugin, in_events: ?*const c.clap.clap_input_events_t) void {
        const ev = in_events orelse return;
        const size_fn = ev.size orelse return;
        const get_fn = ev.get orelse return;
        const n = size_fn(ev);
        var i: u32 = 0;
        while (i < n) : (i += 1) {
            const hdr = get_fn(ev, i);
            if (hdr == null) continue;
            if (hdr.*.space_id != c.clap.CLAP_CORE_EVENT_SPACE_ID) continue;
            switch (hdr.*.type) {
                c.clap.CLAP_EVENT_PARAM_VALUE => {
                    const pv: *const c.clap.clap_event_param_value_t = @ptrCast(@alignCast(hdr));
                    self.params.setRaw(pv.param_id, pv.value);
                },
                else => {},
            }
        }
    }

    /// Ask the host to re-read every parameter value. Must be called on the
    /// main thread after `state.load` changes values, so the host's automation
    /// lanes and generic UI stay in sync with the restored state.
    fn notifyParamsRescan(self: *Plugin) void {
        const host = self.host orelse return;
        const get_ext = host.*.get_extension orelse return;
        const raw = get_ext(host, c.clap.CLAP_EXT_PARAMS) orelse return;
        const host_params: *const c.clap.clap_host_params_t = @ptrCast(@alignCast(raw));
        const rescan = host_params.rescan orelse return;
        rescan(host, c.clap.CLAP_PARAM_RESCAN_VALUES);
    }

    /// Push the current parameter values into the DSP engine's controls.
    fn syncEngine(self: *Plugin) void {
        self.engine.setControls(.{
            .gain = @floatCast(self.params.get(.gain)),
            .bass = @floatCast(self.params.get(.bass)),
            .treble = @floatCast(self.params.get(.treble)),
            .hf_drive = @floatCast(self.params.get(.hf_drive)),
            .fac = @floatCast(self.params.get(.fac)),
            .volume = @floatCast(self.params.get(.volume)),
            .output_db = @floatCast(self.params.get(.output)),
            .bypass = self.params.get(.bypass) >= 0.5,
        });
    }

    /// Drain GUI-originated parameter changes into the host's output event
    /// queue as gesture/value events, closing the automation loop.
    fn drainChanges(self: *Plugin, out_events: ?*const c.clap.clap_output_events_t) void {
        const oe = out_events orelse return;
        const push = oe.*.try_push orelse return;
        while (self.changes.pop()) |change| {
            switch (change.kind) {
                .gesture_begin, .gesture_end => {
                    var ev = c.clap.clap_event_param_gesture_t{
                        .header = .{
                            .size = @sizeOf(c.clap.clap_event_param_gesture_t),
                            .time = 0,
                            .space_id = c.clap.CLAP_CORE_EVENT_SPACE_ID,
                            .type = if (change.kind == .gesture_begin)
                                c.clap.CLAP_EVENT_PARAM_GESTURE_BEGIN
                            else
                                c.clap.CLAP_EVENT_PARAM_GESTURE_END,
                            .flags = 0,
                        },
                        .param_id = change.id,
                    };
                    _ = push(oe, &ev.header);
                },
                .value => {
                    var ev = c.clap.clap_event_param_value_t{
                        .header = .{
                            .size = @sizeOf(c.clap.clap_event_param_value_t),
                            .time = 0,
                            .space_id = c.clap.CLAP_CORE_EVENT_SPACE_ID,
                            .type = c.clap.CLAP_EVENT_PARAM_VALUE,
                            .flags = 0,
                        },
                        .param_id = change.id,
                        .cookie = null,
                        .note_id = -1,
                        .port_index = -1,
                        .channel = -1,
                        .key = -1,
                        .value = change.value,
                    };
                    _ = push(oe, &ev.header);
                },
            }
        }
    }
};

/// Callback handed to the GUI: ask the host to flush parameter output events so
/// GUI edits reach the host even while audio is stopped.
fn requestFlush(ctx: ?*anyopaque) void {
    const self: *Plugin = @ptrCast(@alignCast(ctx orelse return));
    const host = self.host;
    if (host == null) return;
    const get_ext = host.*.get_extension orelse return;
    const ext = get_ext(host, c.clap.CLAP_EXT_PARAMS);
    if (ext == null) return;
    const host_params: *const c.clap.clap_host_params_t = @ptrCast(@alignCast(ext));
    if (host_params.request_flush) |rf| rf(host);
}

fn pluginInit(plugin: [*c]const c.clap.clap_plugin_t) callconv(.c) bool {
    _ = plugin;
    return true;
}

fn pluginDestroy(plugin: [*c]const c.clap.clap_plugin_t) callconv(.c) void {
    const self = Plugin.fromClap(plugin);
    if (self.gui) |g| g.destroy();
    allocator.destroy(self);
}

fn pluginActivate(
    plugin: [*c]const c.clap.clap_plugin_t,
    sample_rate: f64,
    min_frames: u32,
    max_frames: u32,
) callconv(.c) bool {
    _ = min_frames;
    _ = max_frames;
    const self = Plugin.fromClap(plugin);
    self.engine.prepare(sample_rate);
    self.engine.reset();
    self.syncEngine();
    return true;
}

fn pluginDeactivate(plugin: [*c]const c.clap.clap_plugin_t) callconv(.c) void {
    _ = plugin;
}

fn pluginStartProcessing(plugin: [*c]const c.clap.clap_plugin_t) callconv(.c) bool {
    _ = plugin;
    return true;
}

fn pluginStopProcessing(plugin: [*c]const c.clap.clap_plugin_t) callconv(.c) void {
    _ = plugin;
}

fn pluginReset(plugin: [*c]const c.clap.clap_plugin_t) callconv(.c) void {
    const self = Plugin.fromClap(plugin);
    self.engine.reset();
}

fn pluginProcess(
    plugin: [*c]const c.clap.clap_plugin_t,
    process: [*c]const c.clap.clap_process_t,
) callconv(.c) c.clap.clap_process_status {
    const self = Plugin.fromClap(plugin);
    if (process == null) return c.clap.CLAP_PROCESS_ERROR;

    self.applyInputEvents(process.*.in_events);
    self.syncEngine();
    self.drainChanges(process.*.out_events);
    if (process.*.audio_outputs_count == 0) return c.clap.CLAP_PROCESS_CONTINUE;

    const nframes = process.*.frames_count;
    const out = &process.*.audio_outputs[0];
    if (out.*.data32 == null) return c.clap.CLAP_PROCESS_CONTINUE;

    // Copy inputs to outputs when the host provides distinct buffers.
    if (process.*.audio_inputs_count > 0) {
        const in = &process.*.audio_inputs[0];
        if (in.*.data32 != null) {
            const nch = @min(out.*.channel_count, in.*.channel_count);
            var ch: u32 = 0;
            while (ch < nch) : (ch += 1) {
                const dst = out.*.data32[ch];
                const src = in.*.data32[ch];
                if (dst != src) {
                    @memcpy(dst[0..nframes], src[0..nframes]);
                }
            }
        }
    }

    // Run the amp engine on the stereo output in place.
    if (out.*.channel_count >= 2) {
        const l = out.*.data32[0][0..nframes];
        const r = out.*.data32[1][0..nframes];
        self.engine.processBlock(l, r);
    }

    return c.clap.CLAP_PROCESS_CONTINUE;
}

fn pluginGetExtension(
    plugin: [*c]const c.clap.clap_plugin_t,
    id: [*c]const u8,
) callconv(.c) ?*const anyopaque {
    _ = plugin;
    if (cstrEql(id, c.clap.CLAP_EXT_AUDIO_PORTS)) return &audio_ports_ext;
    if (cstrEql(id, c.clap.CLAP_EXT_PARAMS)) return &params_ext;
    if (cstrEql(id, c.clap.CLAP_EXT_STATE)) return &state_ext;
    if (cstrEql(id, c.clap.CLAP_EXT_GUI)) return &gui_ext;
    return null;
}

fn pluginOnMainThread(plugin: [*c]const c.clap.clap_plugin_t) callconv(.c) void {
    _ = plugin;
}

// ---------------------------------------------------------------------------
// Audio ports extension
// ---------------------------------------------------------------------------

const audio_ports_ext = c.clap.clap_plugin_audio_ports_t{
    .count = audioPortsCount,
    .get = audioPortsGet,
};

fn audioPortsCount(
    plugin: [*c]const c.clap.clap_plugin_t,
    is_input: bool,
) callconv(.c) u32 {
    _ = plugin;
    _ = is_input;
    return 1;
}

fn audioPortsGet(
    plugin: [*c]const c.clap.clap_plugin_t,
    index: u32,
    is_input: bool,
    info: [*c]c.clap.clap_audio_port_info_t,
) callconv(.c) bool {
    _ = plugin;
    if (index != 0) return false;
    info.*.id = 0;
    copyName(&info.*.name[0], if (is_input) "Input" else "Output");
    info.*.channel_count = 2;
    info.*.flags = c.clap.CLAP_AUDIO_PORT_IS_MAIN;
    info.*.port_type = c.clap.CLAP_PORT_STEREO;
    info.*.in_place_pair = c.clap.CLAP_INVALID_ID;
    return true;
}

// ---------------------------------------------------------------------------
// Params extension
// ---------------------------------------------------------------------------

const params_ext = c.clap.clap_plugin_params_t{
    .count = paramsCount,
    .get_info = paramsGetInfo,
    .get_value = paramsGetValue,
    .value_to_text = paramsValueToText,
    .text_to_value = paramsTextToValue,
    .flush = paramsFlush,
};

fn paramsCount(plugin: [*c]const c.clap.clap_plugin_t) callconv(.c) u32 {
    _ = plugin;
    return params.count;
}

fn paramsGetInfo(
    plugin: [*c]const c.clap.clap_plugin_t,
    index: u32,
    info: [*c]c.clap.clap_param_info_t,
) callconv(.c) bool {
    _ = plugin;
    if (index >= params.count) return false;
    const d = params.descriptors[index];
    info.*.id = @intFromEnum(d.id);
    info.*.flags = d.flags;
    info.*.cookie = null;
    copyName(&info.*.name[0], d.name);
    copyName(&info.*.module[0], "");
    info.*.min_value = d.min;
    info.*.max_value = d.max;
    info.*.default_value = d.default;
    return true;
}

fn paramsGetValue(
    plugin: [*c]const c.clap.clap_plugin_t,
    param_id: c.clap.clap_id,
    out_value: [*c]f64,
) callconv(.c) bool {
    const self = Plugin.fromClap(plugin);
    if (param_id >= params.count) return false;
    const id: params.ParamId = @enumFromInt(param_id);
    out_value.* = self.params.get(id);
    return true;
}

fn paramsValueToText(
    plugin: [*c]const c.clap.clap_plugin_t,
    param_id: c.clap.clap_id,
    value: f64,
    out_buffer: [*c]u8,
    out_capacity: u32,
) callconv(.c) bool {
    _ = plugin;
    if (out_capacity == 0) return false;
    if (param_id >= params.count) return false;
    const id: params.ParamId = @enumFromInt(param_id);
    const dst = out_buffer[0 .. out_capacity - 1];
    const text = switch (id) {
        .bypass => std.fmt.bufPrint(dst, "{s}", .{if (value >= 0.5) "On" else "Off"}),
        .output => std.fmt.bufPrint(dst, "{d:.1} dB", .{value}),
        .fac => std.fmt.bufPrint(dst, "{d:.0}", .{@round(value) + 1}),
        else => std.fmt.bufPrint(dst, "{d:.1}", .{value}),
    } catch return false;
    out_buffer[text.len] = 0;
    return true;
}

fn paramsTextToValue(
    plugin: [*c]const c.clap.clap_plugin_t,
    param_id: c.clap.clap_id,
    param_value_text: [*c]const u8,
    out_value: [*c]f64,
) callconv(.c) bool {
    _ = plugin;
    if (param_id >= params.count) return false;
    const id: params.ParamId = @enumFromInt(param_id);
    const s = std.mem.trim(u8, std.mem.sliceTo(param_value_text, 0), " \t");
    if (id == .bypass) {
        out_value.* = if (std.ascii.eqlIgnoreCase(s, "on") or std.mem.eql(u8, s, "1")) 1 else 0;
        return true;
    }
    // Parse the leading numeric token, ignoring any trailing unit (e.g. " dB").
    var end: usize = 0;
    while (end < s.len) : (end += 1) {
        const ch = s[end];
        if (!(std.ascii.isDigit(ch) or ch == '.' or ch == '-' or ch == '+' or ch == 'e' or ch == 'E')) break;
    }
    const v = std.fmt.parseFloat(f64, s[0..end]) catch return false;
    // F.A.C. is displayed as a 1-based position; invert that back to the raw value.
    out_value.* = if (id == .fac) v - 1.0 else v;
    return true;
}

fn paramsFlush(
    plugin: [*c]const c.clap.clap_plugin_t,
    in_events: [*c]const c.clap.clap_input_events_t,
    out_events: [*c]const c.clap.clap_output_events_t,
) callconv(.c) void {
    const self = Plugin.fromClap(plugin);
    self.applyInputEvents(in_events);
    self.syncEngine();
    self.drainChanges(out_events);
}

// ---------------------------------------------------------------------------
// State extension
// ---------------------------------------------------------------------------

const state_version: u32 = 1;

const state_ext = c.clap.clap_plugin_state_t{
    .save = stateSave,
    .load = stateLoad,
};

fn stateSave(
    plugin: [*c]const c.clap.clap_plugin_t,
    stream: [*c]const c.clap.clap_ostream_t,
) callconv(.c) bool {
    const self = Plugin.fromClap(plugin);
    var buf: [8 + params.count * 8]u8 = undefined;
    std.mem.writeInt(u32, buf[0..4], state_version, .little);
    std.mem.writeInt(u32, buf[4..8], params.count, .little);
    var i: usize = 0;
    while (i < params.count) : (i += 1) {
        const bits: u64 = @bitCast(self.params.values[i].load(.monotonic));
        std.mem.writeInt(u64, buf[8 + i * 8 ..][0..8], bits, .little);
    }
    return writeAll(stream, &buf);
}

fn stateLoad(
    plugin: [*c]const c.clap.clap_plugin_t,
    stream: [*c]const c.clap.clap_istream_t,
) callconv(.c) bool {
    const self = Plugin.fromClap(plugin);
    var hdr: [8]u8 = undefined;
    if (!readAll(stream, &hdr)) return false;
    _ = std.mem.readInt(u32, hdr[0..4], .little); // version (currently unused)
    const cnt = std.mem.readInt(u32, hdr[4..8], .little);
    var i: u32 = 0;
    while (i < cnt) : (i += 1) {
        var b: [8]u8 = undefined;
        if (!readAll(stream, &b)) return false;
        const v: f64 = @bitCast(std.mem.readInt(u64, &b, .little));
        self.params.setRaw(i, v);
    }
    self.syncEngine();
    self.notifyParamsRescan();
    return true;
}

fn writeAll(stream: [*c]const c.clap.clap_ostream_t, bytes: []const u8) bool {
    const write_fn = stream.*.write orelse return false;
    var off: usize = 0;
    while (off < bytes.len) {
        const n = write_fn(stream, @ptrCast(bytes.ptr + off), bytes.len - off);
        if (n <= 0) return false;
        off += @intCast(n);
    }
    return true;
}

fn readAll(stream: [*c]const c.clap.clap_istream_t, bytes: []u8) bool {
    const read_fn = stream.*.read orelse return false;
    var off: usize = 0;
    while (off < bytes.len) {
        const n = read_fn(stream, @ptrCast(bytes.ptr + off), bytes.len - off);
        if (n <= 0) return false;
        off += @intCast(n);
    }
    return true;
}

// ---------------------------------------------------------------------------
// GUI extension
// ---------------------------------------------------------------------------

const gui_ext = c.clap.clap_plugin_gui_t{
    .is_api_supported = guiIsApiSupported,
    .get_preferred_api = guiGetPreferredApi,
    .create = guiCreate,
    .destroy = guiDestroy,
    .set_scale = guiSetScale,
    .get_size = guiGetSize,
    .can_resize = guiCanResize,
    .get_resize_hints = guiGetResizeHints,
    .adjust_size = guiAdjustSize,
    .set_size = guiSetSize,
    .set_parent = guiSetParent,
    .set_transient = guiSetTransient,
    .suggest_title = guiSuggestTitle,
    .show = guiShow,
    .hide = guiHide,
};

fn apiIsWin32(api: [*c]const u8) bool {
    return cstrEql(api, c.clap.CLAP_WINDOW_API_WIN32);
}

fn guiIsApiSupported(plugin: [*c]const c.clap.clap_plugin_t, api: [*c]const u8, is_floating: bool) callconv(.c) bool {
    _ = plugin;
    return apiIsWin32(api) and !is_floating;
}

fn guiGetPreferredApi(plugin: [*c]const c.clap.clap_plugin_t, api: [*c][*c]const u8, is_floating: [*c]bool) callconv(.c) bool {
    _ = plugin;
    api.* = c.clap.CLAP_WINDOW_API_WIN32;
    is_floating.* = false;
    return true;
}

fn guiCreate(plugin: [*c]const c.clap.clap_plugin_t, api: [*c]const u8, is_floating: bool) callconv(.c) bool {
    if (!apiIsWin32(api) or is_floating) return false;
    const self = Plugin.fromClap(plugin);
    if (self.gui != null) return true;
    self.gui = guimod.Gui.create(allocator, .{
        .state = &self.params,
        .queue = &self.changes,
        .request_flush_ctx = self,
        .request_flush_fn = requestFlush,
    }) catch return false;
    return true;
}

fn guiDestroy(plugin: [*c]const c.clap.clap_plugin_t) callconv(.c) void {
    const self = Plugin.fromClap(plugin);
    if (self.gui) |g| {
        g.destroy();
        self.gui = null;
    }
}

fn guiSetScale(plugin: [*c]const c.clap.clap_plugin_t, scale: f64) callconv(.c) bool {
    _ = plugin;
    _ = scale;
    return false;
}

fn guiGetSize(plugin: [*c]const c.clap.clap_plugin_t, width: [*c]u32, height: [*c]u32) callconv(.c) bool {
    const self = Plugin.fromClap(plugin);
    if (self.gui) |g| {
        g.getSize(width, height);
    } else {
        width.* = guimod.default_width;
        height.* = guimod.default_height;
    }
    return true;
}

fn guiCanResize(plugin: [*c]const c.clap.clap_plugin_t) callconv(.c) bool {
    _ = plugin;
    return false;
}

fn guiGetResizeHints(plugin: [*c]const c.clap.clap_plugin_t, hints: [*c]c.clap.clap_gui_resize_hints_t) callconv(.c) bool {
    _ = plugin;
    hints.*.can_resize_horizontally = false;
    hints.*.can_resize_vertically = false;
    hints.*.preserve_aspect_ratio = true;
    hints.*.aspect_ratio_width = guimod.default_width;
    hints.*.aspect_ratio_height = guimod.default_height;
    return true;
}

fn guiAdjustSize(plugin: [*c]const c.clap.clap_plugin_t, width: [*c]u32, height: [*c]u32) callconv(.c) bool {
    _ = plugin;
    width.* = guimod.default_width;
    height.* = guimod.default_height;
    return true;
}

fn guiSetSize(plugin: [*c]const c.clap.clap_plugin_t, width: u32, height: u32) callconv(.c) bool {
    const self = Plugin.fromClap(plugin);
    if (self.gui) |g| g.setSize(width, height);
    return true;
}

fn guiSetParent(plugin: [*c]const c.clap.clap_plugin_t, window: [*c]const c.clap.clap_window_t) callconv(.c) bool {
    if (window == null) return false;
    const self = Plugin.fromClap(plugin);
    const g = self.gui orelse return false;
    if (!apiIsWin32(window.*.api)) return false;
    return g.setParent(window.*.handle.win32);
}

fn guiSetTransient(plugin: [*c]const c.clap.clap_plugin_t, window: [*c]const c.clap.clap_window_t) callconv(.c) bool {
    _ = plugin;
    _ = window;
    return false;
}

fn guiSuggestTitle(plugin: [*c]const c.clap.clap_plugin_t, title: [*c]const u8) callconv(.c) void {
    _ = plugin;
    _ = title;
}

fn guiShow(plugin: [*c]const c.clap.clap_plugin_t) callconv(.c) bool {
    const self = Plugin.fromClap(plugin);
    const g = self.gui orelse return false;
    g.show();
    return true;
}

fn guiHide(plugin: [*c]const c.clap.clap_plugin_t) callconv(.c) bool {
    const self = Plugin.fromClap(plugin);
    const g = self.gui orelse return false;
    g.hide();
    return true;
}

// ---------------------------------------------------------------------------
// Plugin factory
// ---------------------------------------------------------------------------

const plugin_factory = c.clap.clap_plugin_factory_t{
    .get_plugin_count = factoryGetPluginCount,
    .get_plugin_descriptor = factoryGetPluginDescriptor,
    .create_plugin = factoryCreatePlugin,
};

fn factoryGetPluginCount(
    factory: [*c]const c.clap.clap_plugin_factory_t,
) callconv(.c) u32 {
    _ = factory;
    return 1;
}

fn factoryGetPluginDescriptor(
    factory: [*c]const c.clap.clap_plugin_factory_t,
    index: u32,
) callconv(.c) [*c]const c.clap.clap_plugin_descriptor_t {
    _ = factory;
    if (index != 0) return null;
    return &descriptor;
}

fn factoryCreatePlugin(
    factory: [*c]const c.clap.clap_plugin_factory_t,
    host: [*c]const c.clap.clap_host_t,
    id: [*c]const u8,
) callconv(.c) [*c]const c.clap.clap_plugin_t {
    _ = factory;
    if (!cstrEql(id, plugin_id)) return null;

    const self = allocator.create(Plugin) catch return null;
    self.* = .{
        .clap_plugin = .{
            .desc = &descriptor,
            .plugin_data = self,
            .init = pluginInit,
            .destroy = pluginDestroy,
            .activate = pluginActivate,
            .deactivate = pluginDeactivate,
            .start_processing = pluginStartProcessing,
            .stop_processing = pluginStopProcessing,
            .reset = pluginReset,
            .process = pluginProcess,
            .get_extension = pluginGetExtension,
            .on_main_thread = pluginOnMainThread,
        },
        .host = host,
        .engine = dsp.Engine.init(),
        .params = params.State.init(),
        .gui = null,
    };
    return &self.clap_plugin;
}

// ---------------------------------------------------------------------------
// Entry point (exported symbol scanned by the host)
// ---------------------------------------------------------------------------

fn entryInit(plugin_path: [*c]const u8) callconv(.c) bool {
    _ = plugin_path;
    return true;
}

fn entryDeinit() callconv(.c) void {}

fn entryGetFactory(factory_id: [*c]const u8) callconv(.c) ?*const anyopaque {
    if (cstrEql(factory_id, c.clap.CLAP_PLUGIN_FACTORY_ID)) return &plugin_factory;
    return null;
}

export const clap_entry = c.clap.clap_plugin_entry_t{
    .clap_version = .{
        .major = c.clap.CLAP_VERSION_MAJOR,
        .minor = c.clap.CLAP_VERSION_MINOR,
        .revision = c.clap.CLAP_VERSION_REVISION,
    },
    .init = entryInit,
    .deinit = entryDeinit,
    .get_factory = entryGetFactory,
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn cstrEql(a: [*c]const u8, b: []const u8) bool {
    return std.mem.eql(u8, std.mem.sliceTo(a, 0), b);
}

fn copyName(dst: [*c]u8, name: []const u8) void {
    const cap: usize = @intCast(c.clap.CLAP_NAME_SIZE);
    const n = @min(name.len, cap - 1);
    @memcpy(dst[0..n], name[0..n]);
    dst[n] = 0;
}
