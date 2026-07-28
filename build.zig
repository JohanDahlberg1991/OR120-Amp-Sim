const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ---- The CLAP plugin (a shared library exporting `clap_entry`) ----
    const plugin_mod = b.createModule(.{
        .root_source_file = b.path("src/clap_plugin.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // Clay UI library (single-header C) plus its implementation TU.
    plugin_mod.addIncludePath(b.path("vendor/clay"));
    plugin_mod.addCSourceFile(.{ .file = b.path("src/gui/clay_impl.c"), .flags = &.{} });

    // Win32 windowing + OpenGL used by the GUI backend.
    plugin_mod.linkSystemLibrary("user32", .{});
    plugin_mod.linkSystemLibrary("gdi32", .{});
    plugin_mod.linkSystemLibrary("opengl32", .{});
    plugin_mod.linkSystemLibrary("kernel32", .{});

    const plugin = b.addLibrary(.{
        .name = "OR120AmpSim",
        .root_module = plugin_mod,
        .linkage = .dynamic,
    });

    // Install the artifact renamed to the `.clap` extension.
    const install_clap = b.addInstallArtifact(plugin, .{
        .dest_dir = .{ .override = .{ .custom = "clap" } },
        .dest_sub_path = "OR120AmpSim.clap",
    });
    b.getInstallStep().dependOn(&install_clap.step);

    // ---- Unit tests (pure-Zig DSP) ----
    const dsp_mod = b.createModule(.{
        .root_source_file = b.path("src/dsp/engine.zig"),
        .target = target,
        .optimize = optimize,
    });
    const dsp_tests = b.addTest(.{ .root_module = dsp_mod });
    const run_dsp_tests = b.addRunArtifact(dsp_tests);

    const params_mod = b.createModule(.{
        .root_source_file = b.path("src/params.zig"),
        .target = target,
        .optimize = optimize,
    });
    const params_tests = b.addTest(.{ .root_module = params_mod });
    const run_params_tests = b.addRunArtifact(params_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_dsp_tests.step);
    test_step.dependOn(&run_params_tests.step);
}
