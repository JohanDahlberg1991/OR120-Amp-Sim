# OR120-Amp-Sim

An **Orange OR120** guitar-amplifier simulation, written from scratch in
[Zig](https://ziglang.org/) with a [Clay](https://github.com/nicbarker/clay)
immediate-mode UI. It models the full signal path of the classic OR120 "Graphic"
head — cascaded 12AX7 preamp stages, the passive tone stack, the F.A.C.
(Frequency Analysing Circuit) voicing switch, an EL34 class-AB push-pull power
section with power-supply sag, and a global negative-feedback loop.

The plugin ships in two formats:

- **CLAP** — native, 100 % pure Zig (DSP, GUI, and the CLAP ABI are all hand-written Zig).
- **VST3** — a thin [clap-wrapper](https://github.com/free-audio/clap-wrapper)
  bridge around the _same_ CLAP binary. The wrapper is the only C++ in the
  project; at load time it locates the same-named `OR120AmpSim.clap` and forwards
  the VST3 protocol to it at runtime.

---

## What it models

The amp is simulated per-channel as a chain of analog-inspired stages. Signal
flows top to bottom:

| Stage              | Emulation                                                                              |
| ------------------ | -------------------------------------------------------------------------------------- |
| **V1A preamp**     | 12AX7 triode wave-shaping (`tanh`-based), 2× oversampled                               |
| **Tone stack**     | Baxandall-style bass low-shelf (~300 Hz) + treble high-shelf (~1.6 kHz), ±14 dB        |
| **F.A.C.**         | 6-position stepped high-pass "voicing" filter (25 / 55 / 100 / 180 / 340 / 600 Hz)     |
| **HF Drive**       | Bright high-shelf (~1.5 kHz) feeding a second 12AX7 (V1B) triode stage, 2× oversampled |
| **Phase inverter** | Cathodyne (unity-gain) splitter                                                        |
| **EL34 power amp** | Class-AB push-pull wave-shaper with adjustable bias/crossover, 2× oversampled          |
| **Power supply**   | Dynamic sag envelope that dips the rail under load                                     |
| **Global NFB**     | Negative-feedback loop solved per-sample (Newton iteration)                            |
| **Output**         | DC blocker + output trim                                                               |

### Parameters

| Knob         | Range         | Default | Notes                               |
| ------------ | ------------- | ------- | ----------------------------------- |
| **Gain**     | 0–10          | 5       | Preamp drive                        |
| **Bass**     | 0–10          | 5       | Tone stack low-shelf                |
| **Treble**   | 0–10          | 5       | Tone stack high-shelf               |
| **HF Drive** | 0–10          | 5       | Bright boost into V1B               |
| **F.A.C.**   | 1–6 (stepped) | 3       | Frequency Analysing Circuit voicing |
| **Volume**   | 0–10          | 5       | Power-amp drive                     |
| **Output**   | −24…+24 dB    | 0       | Final level trim                    |
| **Bypass**   | on/off        | off     | Host-recognised bypass              |

All parameters are automatable. Values are held in a thread-safe atomic store and
handed to the audio thread through a lock-free change queue, so the GUI never
blocks or races the DSP.

### User interface

The UI is drawn procedurally — no image assets. Clay lays out the panel while a
small OpenGL overlay renders the tolex-covered chassis (woven-vinyl texture,
vignette, corner screws) and photoreal-ish knobs (spherically-lit bodies, raised
caps, silkscreen tick rings, and cream pointers). Knobs are click-and-drag; the
F.A.C. control detents to its six positions.

---

## Prerequisites

- **Zig** 0.16.0 (dev) — builds the CLAP, GUI, and DSP.
- **git** — fetches the vendored dependencies.
- For the VST3 target only: **CMake** 3.21+ and a **C++17 toolchain** (MSVC on
  Windows).

> The project currently targets **Windows** (Win32 + OpenGL windowing). The DSP
> and CLAP core are portable; only the GUI windowing layer is platform-specific.

---

## Installation guide

### 1. Clone

```powershell
git clone <repo-url> OR120-Amp-Sim
cd OR120-Amp-Sim
```

### 2. Fetch vendored dependencies

This pulls the third-party sources into `vendor/` (CLAP headers, Clay, and, for
the VST3 build, clap-wrapper). `vendor/` is git-ignored.

```powershell
scripts\vendor.ps1
```

### 3. Build the CLAP

```powershell
# Build the CLAP plugin
zig build

# (optional) run the unit-test suite
zig build test
```

Output: **`zig-out/clap/OR120AmpSim.clap`**

### 4. Build the VST3 (optional)

```powershell
scripts\build-vst3.ps1
```

This first builds the CLAP, then configures and builds clap-wrapper. The **first**
CMake configure downloads the CLAP and VST3 SDKs, so it needs network access and
takes a few minutes.

Output: **`zig-out/vst3/OR120AmpSim.vst3`**

Because the VST3 is a thin wrapper that forwards to the CLAP at runtime, you must
**install both files together** for the VST3 to work.

### 5. Install (Windows)

| File               | Destination                                                              |
| ------------------ | ------------------------------------------------------------------------ |
| `OR120AmpSim.clap` | `%CommonProgramFiles%\CLAP\` (or `%LOCALAPPDATA%\Programs\Common\CLAP\`) |
| `OR120AmpSim.vst3` | `%CommonProgramFiles%\VST3\`                                             |

```powershell
Copy-Item zig-out\clap\OR120AmpSim.clap "$env:CommonProgramFiles\CLAP\" -Force
Copy-Item -Recurse zig-out\vst3\OR120AmpSim.vst3 "$env:CommonProgramFiles\VST3\" -Force
```

> **Note:** if the plugin is already loaded in a running DAW, the file is locked
> and the copy will fail with _"being used by another process."_ Close the DAW
> first, then re-run the copy.

### 6. Run

Rescan plugins in your DAW (REAPER, Bitwig, etc.), then insert **OR120AmpSim** on
a guitar track. For a full rig, feed it a cabinet impulse response or amp-cab
capture downstream — this plugin models the amp head only.

---

## Development

```powershell
zig build            # build the CLAP
zig build test       # run the DSP + plugin unit tests
```

The repo vendors a `clap-validator` under `tools/`; run it against the built
plugin to check CLAP conformance:

```powershell
.\tools\clap-validator\clap-validator.exe validate .\zig-out\clap\OR120AmpSim.clap
```

---

## Project layout

- `src/dsp/` — signal chain: preamp/power-amp wave-shaping, tone stack, filters,
  oversampling, and the amp engine.
- `src/gui/` — Clay UI, Win32/OpenGL windowing, procedural knob/panel rendering,
  and knob interaction.
- `src/params.zig` — parameter definitions, atomic state store, lock-free change queue.
- `src/clap_abi.zig`, `src/clap_plugin.zig` — the CLAP ABI and the plugin implementation.
- `scripts/` — dependency vendoring (`vendor.ps1`) and the VST3 build (`build-vst3.ps1`).
- `tools/` — bundled `clap-validator`.
- `vendor/` — fetched third-party sources (git-ignored).
