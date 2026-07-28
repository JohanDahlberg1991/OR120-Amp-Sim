//! Tube-style non-linear waveshapers for the OR120 preamp and power-amp stages.
//!
//! These are cheap, well-behaved approximations of valve transfer curves. They
//! are meant to be run inside an oversampled region (see `oversample.zig`) so
//! the harmonics they generate do not alias.

const std = @import("std");

/// Asymmetric soft-clip approximating a triode gain stage. The `bias` term skews
/// the curve so positive and negative swings clip differently (adds even
/// harmonics); the DC introduced by the bias is removed so the stage stays
/// centred.
pub inline fn triode(x: f32, drive: f32, bias: f32) f32 {
    const v = x * drive + bias;
    return std.math.tanh(v) - std.math.tanh(bias);
}

/// Symmetric-ish power-amp saturation. Softer knee than the preamp with a touch
/// of asymmetry for character. `drive` sets how hard it is pushed.
pub inline fn powerAmp(x: f32, drive: f32) f32 {
    const v = x * drive;
    // Cubic soft clip blended with tanh for a rounder top end.
    const t = std.math.tanh(v);
    const c = if (v > 1.5) 1.0 else if (v < -1.5) -1.0 else v - (v * v * v) / 6.75;
    return 0.5 * (t + c);
}

/// Derivative of `powerAmp(x, 1.0)` with respect to `x`. Used by the power-stage
/// negative-feedback solver to model the closed loop without a delay.
pub inline fn powerAmpDeriv(x: f32) f32 {
    const th = std.math.tanh(x);
    const dt = 1.0 - th * th;
    const dc: f32 = if (x > 1.5 or x < -1.5) 0.0 else 1.0 - (x * x) / 2.25;
    return 0.5 * (dt + dc);
}

/// Push-pull class-AB power section: two EL34 devices biased by ±`bias` and
/// summed. Because the pair is symmetric the transfer is an odd function, so
/// even harmonics cancel and the **odd** harmonics dominate — the "chewy" EL34
/// crunch. `bias` sets the class-AB operating point: near 0 the two knees merge
/// (class-A, smooth), while larger values pull the knees apart and open a
/// low-gain crossover region between them (colder bias, more crossover grit).
/// Normalised to ~±1 for large |x|.
pub inline fn pushPull(x: f32, bias: f32) f32 {
    return 0.5 * (std.math.tanh(x + bias) + std.math.tanh(x - bias));
}

/// Derivative of `pushPull` with respect to `x`, for the NFB solver.
pub inline fn pushPullDeriv(x: f32, bias: f32) f32 {
    const a = std.math.tanh(x + bias);
    const b = std.math.tanh(x - bias);
    return 0.5 * ((1.0 - a * a) + (1.0 - b * b));
}

test "triode is near-linear for tiny signals" {
    const y = triode(0.001, 1.0, 0.0);
    try std.testing.expect(@abs(y - 0.001) < 1e-4);
}

test "triode output stays bounded under huge input" {
    try std.testing.expect(@abs(triode(1000.0, 10.0, 0.2)) < 2.0);
    try std.testing.expect(@abs(triode(-1000.0, 10.0, 0.2)) < 2.0);
}

test "triode bias makes the curve asymmetric" {
    const pos = triode(0.5, 4.0, 0.3);
    const neg = triode(-0.5, 4.0, 0.3);
    try std.testing.expect(@abs(pos) != @abs(neg));
}

test "power amp saturates large signals" {
    try std.testing.expect(@abs(powerAmp(100.0, 5.0)) < 1.2);
}
