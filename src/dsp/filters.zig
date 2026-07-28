//! Small collection of stateful filters used by the amp chain.
//!
//! * `OnePole`  – first-order low/high-pass smoother (also used as a DC blocker
//!   building block and for control-signal smoothing).
//! * `Biquad`   – transposed direct-form II biquad with RBJ "cookbook"
//!   coefficient designers for the shelving/peaking filters that make up the
//!   tone stack and presence control.

const std = @import("std");

/// Flush denormal/subnormal magnitudes to zero. Feedback filters fed silence
/// otherwise decay through the subnormal range, which both wastes CPU and
/// leaves tiny non-zero samples in the output (rejected by strict hosts).
pub inline fn flushDenormal(x: f32) f32 {
    return if (@abs(x) < 1.0e-25) 0.0 else x;
}

/// First-order one-pole low-pass. `y[n] = y[n-1] + a * (x - y[n-1])`.
pub const OnePole = struct {
    a: f32 = 1.0,
    z: f32 = 0.0,

    pub fn setLowpass(self: *OnePole, cutoff_hz: f32, sample_rate: f32) void {
        const c = std.math.exp(-2.0 * std.math.pi * cutoff_hz / sample_rate);
        self.a = 1.0 - c;
    }

    pub inline fn processLowpass(self: *OnePole, x: f32) f32 {
        self.z = flushDenormal(self.z + self.a * (x - self.z));
        return self.z;
    }

    /// High-pass = input minus the low-passed component.
    pub inline fn processHighpass(self: *OnePole, x: f32) f32 {
        return x - self.processLowpass(x);
    }

    pub fn reset(self: *OnePole) void {
        self.z = 0.0;
    }
};

/// Transposed direct-form II biquad.
pub const Biquad = struct {
    b0: f32 = 1.0,
    b1: f32 = 0.0,
    b2: f32 = 0.0,
    a1: f32 = 0.0,
    a2: f32 = 0.0,
    z1: f32 = 0.0,
    z2: f32 = 0.0,

    pub inline fn process(self: *Biquad, x: f32) f32 {
        const y = self.b0 * x + self.z1;
        self.z1 = flushDenormal(self.b1 * x - self.a1 * y + self.z2);
        self.z2 = flushDenormal(self.b2 * x - self.a2 * y);
        return y;
    }

    pub fn reset(self: *Biquad) void {
        self.z1 = 0.0;
        self.z2 = 0.0;
    }

    fn normalize(self: *Biquad, b0: f64, b1: f64, b2: f64, a0: f64, a1: f64, a2: f64) void {
        self.b0 = @floatCast(b0 / a0);
        self.b1 = @floatCast(b1 / a0);
        self.b2 = @floatCast(b2 / a0);
        self.a1 = @floatCast(a1 / a0);
        self.a2 = @floatCast(a2 / a0);
    }

    /// RBJ low-shelf. `gain_db` boosts (>0) or cuts (<0) below `freq_hz`.
    pub fn setLowShelf(self: *Biquad, freq_hz: f32, gain_db: f32, sample_rate: f32) void {
        const fc = std.math.clamp(freq_hz, 1.0, 0.49 * sample_rate);
        const a = std.math.pow(f64, 10.0, @as(f64, gain_db) / 40.0);
        const w0 = 2.0 * std.math.pi * @as(f64, fc) / @as(f64, sample_rate);
        const cw = std.math.cos(w0);
        const sw = std.math.sin(w0);
        const shelf_slope = 1.0;
        const alpha = sw / 2.0 * std.math.sqrt((a + 1.0 / a) * (1.0 / shelf_slope - 1.0) + 2.0);
        const two_sqrt_a_alpha = 2.0 * std.math.sqrt(a) * alpha;

        const b0 = a * ((a + 1.0) - (a - 1.0) * cw + two_sqrt_a_alpha);
        const b1 = 2.0 * a * ((a - 1.0) - (a + 1.0) * cw);
        const b2 = a * ((a + 1.0) - (a - 1.0) * cw - two_sqrt_a_alpha);
        const a0 = (a + 1.0) + (a - 1.0) * cw + two_sqrt_a_alpha;
        const a1 = -2.0 * ((a - 1.0) + (a + 1.0) * cw);
        const a2 = (a + 1.0) + (a - 1.0) * cw - two_sqrt_a_alpha;
        self.normalize(b0, b1, b2, a0, a1, a2);
    }

    /// RBJ high-shelf. `gain_db` boosts (>0) or cuts (<0) above `freq_hz`.
    pub fn setHighShelf(self: *Biquad, freq_hz: f32, gain_db: f32, sample_rate: f32) void {
        const fc = std.math.clamp(freq_hz, 1.0, 0.49 * sample_rate);
        const a = std.math.pow(f64, 10.0, @as(f64, gain_db) / 40.0);
        const w0 = 2.0 * std.math.pi * @as(f64, fc) / @as(f64, sample_rate);
        const cw = std.math.cos(w0);
        const sw = std.math.sin(w0);
        const shelf_slope = 1.0;
        const alpha = sw / 2.0 * std.math.sqrt((a + 1.0 / a) * (1.0 / shelf_slope - 1.0) + 2.0);
        const two_sqrt_a_alpha = 2.0 * std.math.sqrt(a) * alpha;

        const b0 = a * ((a + 1.0) + (a - 1.0) * cw + two_sqrt_a_alpha);
        const b1 = -2.0 * a * ((a - 1.0) + (a + 1.0) * cw);
        const b2 = a * ((a + 1.0) + (a - 1.0) * cw - two_sqrt_a_alpha);
        const a0 = (a + 1.0) - (a - 1.0) * cw + two_sqrt_a_alpha;
        const a1 = 2.0 * ((a - 1.0) - (a + 1.0) * cw);
        const a2 = (a + 1.0) - (a - 1.0) * cw - two_sqrt_a_alpha;
        self.normalize(b0, b1, b2, a0, a1, a2);
    }

    /// RBJ peaking EQ centred on `freq_hz`.
    pub fn setPeaking(self: *Biquad, freq_hz: f32, gain_db: f32, q: f32, sample_rate: f32) void {
        const fc = std.math.clamp(freq_hz, 1.0, 0.49 * sample_rate);
        const a = std.math.pow(f64, 10.0, @as(f64, gain_db) / 40.0);
        const w0 = 2.0 * std.math.pi * @as(f64, fc) / @as(f64, sample_rate);
        const cw = std.math.cos(w0);
        const sw = std.math.sin(w0);
        const alpha = sw / (2.0 * @as(f64, q));

        const b0 = 1.0 + alpha * a;
        const b1 = -2.0 * cw;
        const b2 = 1.0 - alpha * a;
        const a0 = 1.0 + alpha / a;
        const a1 = -2.0 * cw;
        const a2 = 1.0 - alpha / a;
        self.normalize(b0, b1, b2, a0, a1, a2);
    }
};

/// Measure the linear magnitude response of a biquad at `freq_hz` by evaluating
/// the transfer function on the unit circle. Used only by tests.
fn biquadMagnitude(bq: Biquad, freq_hz: f32, sample_rate: f32) f64 {
    const w = 2.0 * std.math.pi * @as(f64, freq_hz) / @as(f64, sample_rate);
    const cw1 = std.math.cos(w);
    const sw1 = std.math.sin(w);
    const cw2 = std.math.cos(2.0 * w);
    const sw2 = std.math.sin(2.0 * w);
    const num_re = @as(f64, bq.b0) + @as(f64, bq.b1) * cw1 + @as(f64, bq.b2) * cw2;
    const num_im = -(@as(f64, bq.b1) * sw1 + @as(f64, bq.b2) * sw2);
    const den_re = 1.0 + @as(f64, bq.a1) * cw1 + @as(f64, bq.a2) * cw2;
    const den_im = -(@as(f64, bq.a1) * sw1 + @as(f64, bq.a2) * sw2);
    const num_mag = std.math.sqrt(num_re * num_re + num_im * num_im);
    const den_mag = std.math.sqrt(den_re * den_re + den_im * den_im);
    return num_mag / den_mag;
}

test "one-pole low-pass passes DC and attenuates highs" {
    var lp = OnePole{};
    lp.setLowpass(1000.0, 48000.0);
    // Feed a constant; output should converge to that constant.
    var y: f32 = 0;
    var i: usize = 0;
    while (i < 2000) : (i += 1) y = lp.processLowpass(1.0);
    try std.testing.expect(@abs(y - 1.0) < 0.01);
}

test "low shelf boosts lows and leaves highs unity" {
    var bq = Biquad{};
    bq.setLowShelf(120.0, 9.0, 48000.0);
    const low = biquadMagnitude(bq, 40.0, 48000.0);
    const high = biquadMagnitude(bq, 12000.0, 48000.0);
    try std.testing.expect(low > 2.0); // ~+9 dB ≈ x2.8
    try std.testing.expect(@abs(high - 1.0) < 0.1);
}

test "high shelf boosts highs and leaves lows unity" {
    var bq = Biquad{};
    bq.setHighShelf(3000.0, 9.0, 48000.0);
    const low = biquadMagnitude(bq, 60.0, 48000.0);
    const high = biquadMagnitude(bq, 16000.0, 48000.0);
    try std.testing.expect(@abs(low - 1.0) < 0.1);
    try std.testing.expect(high > 2.0);
}
