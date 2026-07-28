//! Minimal, hand-written CLAP 1.x ABI binding in pure Zig.
//!
//! Zig's C translator (aro) fails to deduplicate CLAP's `#pragma once` headers
//! when they are reached through `..` relative paths, producing hundreds of
//! spurious "redefinition" errors. Since CLAP's C ABI is frozen for the 1.x
//! series, we mirror the exact struct layouts and function-pointer signatures
//! here. This keeps the whole project in Zig with no C-header translation.
//!
//! Only the subset currently needed is defined; later phases (params, state,
//! gui) extend this file.

// ---------------------------------------------------------------------------
// Version
// ---------------------------------------------------------------------------

pub const CLAP_VERSION_MAJOR: u32 = 1;
pub const CLAP_VERSION_MINOR: u32 = 2;
pub const CLAP_VERSION_REVISION: u32 = 6;

pub const clap_version = extern struct {
    major: u32,
    minor: u32,
    revision: u32,
};
pub const clap_version_t = clap_version;

// ---------------------------------------------------------------------------
// Common typedefs / constants
// ---------------------------------------------------------------------------

pub const clap_id = u32;
pub const CLAP_INVALID_ID: clap_id = 0xFFFF_FFFF;
pub const CLAP_NAME_SIZE: usize = 256;
pub const CLAP_PATH_SIZE: usize = 1024;

pub const CLAP_PLUGIN_FACTORY_ID = "clap.plugin-factory";

pub const CLAP_PLUGIN_FEATURE_INSTRUMENT = "instrument";
pub const CLAP_PLUGIN_FEATURE_AUDIO_EFFECT = "audio-effect";
pub const CLAP_PLUGIN_FEATURE_DISTORTION = "distortion";
pub const CLAP_PLUGIN_FEATURE_STEREO = "stereo";
pub const CLAP_PLUGIN_FEATURE_MONO = "mono";

// ---------------------------------------------------------------------------
// Host
// ---------------------------------------------------------------------------

pub const clap_host = extern struct {
    clap_version: clap_version_t,
    host_data: ?*anyopaque,
    name: [*c]const u8,
    vendor: [*c]const u8,
    url: [*c]const u8,
    version: [*c]const u8,
    get_extension: ?*const fn ([*c]const clap_host, [*c]const u8) callconv(.c) ?*const anyopaque,
    request_restart: ?*const fn ([*c]const clap_host) callconv(.c) void,
    request_process: ?*const fn ([*c]const clap_host) callconv(.c) void,
    request_callback: ?*const fn ([*c]const clap_host) callconv(.c) void,
};
pub const clap_host_t = clap_host;

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

pub const CLAP_CORE_EVENT_SPACE_ID: u16 = 0;

pub const CLAP_EVENT_PARAM_VALUE: u16 = 5;
pub const CLAP_EVENT_PARAM_MOD: u16 = 6;
pub const CLAP_EVENT_PARAM_GESTURE_BEGIN: u16 = 7;
pub const CLAP_EVENT_PARAM_GESTURE_END: u16 = 8;

pub const clap_event_header = extern struct {
    size: u32,
    time: u32,
    space_id: u16,
    type: u16,
    flags: u32,
};
pub const clap_event_header_t = clap_event_header;

pub const clap_event_param_value = extern struct {
    header: clap_event_header_t,
    param_id: clap_id,
    cookie: ?*anyopaque,
    note_id: i32,
    port_index: i16,
    channel: i16,
    key: i16,
    value: f64,
};
pub const clap_event_param_value_t = clap_event_param_value;

pub const clap_event_param_gesture = extern struct {
    header: clap_event_header_t,
    param_id: clap_id,
};
pub const clap_event_param_gesture_t = clap_event_param_gesture;

pub const clap_input_events = extern struct {
    ctx: ?*anyopaque,
    size: ?*const fn ([*c]const clap_input_events) callconv(.c) u32,
    get: ?*const fn ([*c]const clap_input_events, u32) callconv(.c) [*c]const clap_event_header_t,
};
pub const clap_input_events_t = clap_input_events;

pub const clap_output_events = extern struct {
    ctx: ?*anyopaque,
    try_push: ?*const fn ([*c]const clap_output_events, [*c]const clap_event_header_t) callconv(.c) bool,
};
pub const clap_output_events_t = clap_output_events;

// Transport remains opaque until a later phase needs it.
pub const clap_event_transport = opaque {};
pub const clap_event_transport_t = clap_event_transport;

// ---------------------------------------------------------------------------
// Audio buffers & processing
// ---------------------------------------------------------------------------

pub const clap_audio_buffer = extern struct {
    data32: [*c][*c]f32,
    data64: [*c][*c]f64,
    channel_count: u32,
    latency: u32,
    constant_mask: u64,
};
pub const clap_audio_buffer_t = clap_audio_buffer;

pub const clap_process_status = i32;
pub const CLAP_PROCESS_ERROR: clap_process_status = 0;
pub const CLAP_PROCESS_CONTINUE: clap_process_status = 1;
pub const CLAP_PROCESS_CONTINUE_IF_NOT_QUIET: clap_process_status = 2;
pub const CLAP_PROCESS_TAIL: clap_process_status = 3;
pub const CLAP_PROCESS_SLEEP: clap_process_status = 4;

pub const clap_process = extern struct {
    steady_time: i64,
    frames_count: u32,
    transport: ?*const clap_event_transport_t,
    audio_inputs: [*c]const clap_audio_buffer_t,
    audio_outputs: [*c]clap_audio_buffer_t,
    audio_inputs_count: u32,
    audio_outputs_count: u32,
    in_events: ?*const clap_input_events_t,
    out_events: ?*const clap_output_events_t,
};
pub const clap_process_t = clap_process;

// ---------------------------------------------------------------------------
// Plugin descriptor & instance
// ---------------------------------------------------------------------------

pub const clap_plugin_descriptor = extern struct {
    clap_version: clap_version_t,
    id: [*c]const u8,
    name: [*c]const u8,
    vendor: [*c]const u8,
    url: [*c]const u8,
    manual_url: [*c]const u8,
    support_url: [*c]const u8,
    version: [*c]const u8,
    description: [*c]const u8,
    features: [*c]const [*c]const u8,
};
pub const clap_plugin_descriptor_t = clap_plugin_descriptor;

pub const clap_plugin = extern struct {
    desc: [*c]const clap_plugin_descriptor_t,
    plugin_data: ?*anyopaque,
    init: ?*const fn ([*c]const clap_plugin) callconv(.c) bool,
    destroy: ?*const fn ([*c]const clap_plugin) callconv(.c) void,
    activate: ?*const fn ([*c]const clap_plugin, f64, u32, u32) callconv(.c) bool,
    deactivate: ?*const fn ([*c]const clap_plugin) callconv(.c) void,
    start_processing: ?*const fn ([*c]const clap_plugin) callconv(.c) bool,
    stop_processing: ?*const fn ([*c]const clap_plugin) callconv(.c) void,
    reset: ?*const fn ([*c]const clap_plugin) callconv(.c) void,
    process: ?*const fn ([*c]const clap_plugin, [*c]const clap_process_t) callconv(.c) clap_process_status,
    get_extension: ?*const fn ([*c]const clap_plugin, [*c]const u8) callconv(.c) ?*const anyopaque,
    on_main_thread: ?*const fn ([*c]const clap_plugin) callconv(.c) void,
};
pub const clap_plugin_t = clap_plugin;

// ---------------------------------------------------------------------------
// Plugin factory
// ---------------------------------------------------------------------------

pub const clap_plugin_factory = extern struct {
    get_plugin_count: ?*const fn ([*c]const clap_plugin_factory) callconv(.c) u32,
    get_plugin_descriptor: ?*const fn ([*c]const clap_plugin_factory, u32) callconv(.c) [*c]const clap_plugin_descriptor_t,
    create_plugin: ?*const fn ([*c]const clap_plugin_factory, [*c]const clap_host_t, [*c]const u8) callconv(.c) [*c]const clap_plugin_t,
};
pub const clap_plugin_factory_t = clap_plugin_factory;

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

pub const clap_plugin_entry = extern struct {
    clap_version: clap_version_t,
    init: ?*const fn ([*c]const u8) callconv(.c) bool,
    deinit: ?*const fn () callconv(.c) void,
    get_factory: ?*const fn ([*c]const u8) callconv(.c) ?*const anyopaque,
};
pub const clap_plugin_entry_t = clap_plugin_entry;

// ---------------------------------------------------------------------------
// Audio-ports extension
// ---------------------------------------------------------------------------

pub const CLAP_EXT_AUDIO_PORTS = "clap.audio-ports";
pub const CLAP_PORT_MONO = "mono";
pub const CLAP_PORT_STEREO = "stereo";

pub const CLAP_AUDIO_PORT_IS_MAIN: u32 = 1 << 0;
pub const CLAP_AUDIO_PORT_SUPPORTS_64BITS: u32 = 1 << 1;
pub const CLAP_AUDIO_PORT_PREFERS_64BITS: u32 = 1 << 2;
pub const CLAP_AUDIO_PORT_REQUIRES_COMMON_SAMPLE_SIZE: u32 = 1 << 3;

pub const clap_audio_port_info = extern struct {
    id: clap_id,
    name: [CLAP_NAME_SIZE]u8,
    flags: u32,
    channel_count: u32,
    port_type: [*c]const u8,
    in_place_pair: clap_id,
};
pub const clap_audio_port_info_t = clap_audio_port_info;

pub const clap_plugin_audio_ports = extern struct {
    count: ?*const fn ([*c]const clap_plugin_t, bool) callconv(.c) u32,
    get: ?*const fn ([*c]const clap_plugin_t, u32, bool, [*c]clap_audio_port_info_t) callconv(.c) bool,
};
pub const clap_plugin_audio_ports_t = clap_plugin_audio_ports;

// ---------------------------------------------------------------------------
// Params extension
// ---------------------------------------------------------------------------

pub const CLAP_EXT_PARAMS = "clap.params";

pub const CLAP_PARAM_IS_STEPPED: u32 = 1 << 0;
pub const CLAP_PARAM_IS_PERIODIC: u32 = 1 << 1;
pub const CLAP_PARAM_IS_HIDDEN: u32 = 1 << 2;
pub const CLAP_PARAM_IS_READONLY: u32 = 1 << 3;
pub const CLAP_PARAM_IS_BYPASS: u32 = 1 << 4;
pub const CLAP_PARAM_IS_AUTOMATABLE: u32 = 1 << 5;
pub const CLAP_PARAM_IS_MODULATABLE: u32 = 1 << 10;
pub const CLAP_PARAM_REQUIRES_PROCESS: u32 = 1 << 15;

pub const clap_param_info = extern struct {
    id: clap_id,
    flags: u32,
    cookie: ?*anyopaque,
    name: [CLAP_NAME_SIZE]u8,
    module: [CLAP_PATH_SIZE]u8,
    min_value: f64,
    max_value: f64,
    default_value: f64,
};
pub const clap_param_info_t = clap_param_info;

pub const clap_plugin_params = extern struct {
    count: ?*const fn ([*c]const clap_plugin_t) callconv(.c) u32,
    get_info: ?*const fn ([*c]const clap_plugin_t, u32, [*c]clap_param_info_t) callconv(.c) bool,
    get_value: ?*const fn ([*c]const clap_plugin_t, clap_id, [*c]f64) callconv(.c) bool,
    value_to_text: ?*const fn ([*c]const clap_plugin_t, clap_id, f64, [*c]u8, u32) callconv(.c) bool,
    text_to_value: ?*const fn ([*c]const clap_plugin_t, clap_id, [*c]const u8, [*c]f64) callconv(.c) bool,
    flush: ?*const fn ([*c]const clap_plugin_t, [*c]const clap_input_events_t, [*c]const clap_output_events_t) callconv(.c) void,
};
pub const clap_plugin_params_t = clap_plugin_params;

pub const CLAP_PARAM_RESCAN_VALUES: u32 = 1 << 0;
pub const CLAP_PARAM_RESCAN_TEXT: u32 = 1 << 1;
pub const CLAP_PARAM_RESCAN_INFO: u32 = 1 << 2;
pub const CLAP_PARAM_RESCAN_ALL: u32 = 1 << 3;

pub const clap_host_params = extern struct {
    rescan: ?*const fn ([*c]const clap_host_t, u32) callconv(.c) void,
    clear: ?*const fn ([*c]const clap_host_t, clap_id, u32) callconv(.c) void,
    request_flush: ?*const fn ([*c]const clap_host_t) callconv(.c) void,
};
pub const clap_host_params_t = clap_host_params;

// ---------------------------------------------------------------------------
// State extension
// ---------------------------------------------------------------------------

pub const CLAP_EXT_STATE = "clap.state";

pub const clap_istream = extern struct {
    ctx: ?*anyopaque,
    read: ?*const fn ([*c]const clap_istream, ?*anyopaque, u64) callconv(.c) i64,
};
pub const clap_istream_t = clap_istream;

pub const clap_ostream = extern struct {
    ctx: ?*anyopaque,
    write: ?*const fn ([*c]const clap_ostream, ?*const anyopaque, u64) callconv(.c) i64,
};
pub const clap_ostream_t = clap_ostream;

pub const clap_plugin_state = extern struct {
    save: ?*const fn ([*c]const clap_plugin_t, [*c]const clap_ostream_t) callconv(.c) bool,
    load: ?*const fn ([*c]const clap_plugin_t, [*c]const clap_istream_t) callconv(.c) bool,
};
pub const clap_plugin_state_t = clap_plugin_state;

// ---------------------------------------------------------------------------
// GUI extension
// ---------------------------------------------------------------------------

pub const CLAP_EXT_GUI = "clap.gui";

pub const CLAP_WINDOW_API_WIN32 = "win32";
pub const CLAP_WINDOW_API_COCOA = "cocoa";
pub const CLAP_WINDOW_API_X11 = "x11";
pub const CLAP_WINDOW_API_WAYLAND = "wayland";

pub const clap_window = extern struct {
    api: [*c]const u8,
    handle: extern union {
        cocoa: ?*anyopaque,
        x11: c_ulong,
        win32: ?*anyopaque,
        ptr: ?*anyopaque,
    },
};
pub const clap_window_t = clap_window;

pub const clap_gui_resize_hints = extern struct {
    can_resize_horizontally: bool,
    can_resize_vertically: bool,
    preserve_aspect_ratio: bool,
    aspect_ratio_width: u32,
    aspect_ratio_height: u32,
};
pub const clap_gui_resize_hints_t = clap_gui_resize_hints;

pub const clap_plugin_gui = extern struct {
    is_api_supported: ?*const fn ([*c]const clap_plugin_t, [*c]const u8, bool) callconv(.c) bool,
    get_preferred_api: ?*const fn ([*c]const clap_plugin_t, [*c][*c]const u8, [*c]bool) callconv(.c) bool,
    create: ?*const fn ([*c]const clap_plugin_t, [*c]const u8, bool) callconv(.c) bool,
    destroy: ?*const fn ([*c]const clap_plugin_t) callconv(.c) void,
    set_scale: ?*const fn ([*c]const clap_plugin_t, f64) callconv(.c) bool,
    get_size: ?*const fn ([*c]const clap_plugin_t, [*c]u32, [*c]u32) callconv(.c) bool,
    can_resize: ?*const fn ([*c]const clap_plugin_t) callconv(.c) bool,
    get_resize_hints: ?*const fn ([*c]const clap_plugin_t, [*c]clap_gui_resize_hints_t) callconv(.c) bool,
    adjust_size: ?*const fn ([*c]const clap_plugin_t, [*c]u32, [*c]u32) callconv(.c) bool,
    set_size: ?*const fn ([*c]const clap_plugin_t, u32, u32) callconv(.c) bool,
    set_parent: ?*const fn ([*c]const clap_plugin_t, [*c]const clap_window_t) callconv(.c) bool,
    set_transient: ?*const fn ([*c]const clap_plugin_t, [*c]const clap_window_t) callconv(.c) bool,
    suggest_title: ?*const fn ([*c]const clap_plugin_t, [*c]const u8) callconv(.c) void,
    show: ?*const fn ([*c]const clap_plugin_t) callconv(.c) bool,
    hide: ?*const fn ([*c]const clap_plugin_t) callconv(.c) bool,
};
pub const clap_plugin_gui_t = clap_plugin_gui;

pub const clap_host_gui = extern struct {
    resize_hints_changed: ?*const fn ([*c]const clap_host_t) callconv(.c) void,
    request_resize: ?*const fn ([*c]const clap_host_t, u32, u32) callconv(.c) bool,
    request_show: ?*const fn ([*c]const clap_host_t) callconv(.c) bool,
    request_hide: ?*const fn ([*c]const clap_host_t) callconv(.c) bool,
    closed: ?*const fn ([*c]const clap_host_t, bool) callconv(.c) void,
};
pub const clap_host_gui_t = clap_host_gui;
