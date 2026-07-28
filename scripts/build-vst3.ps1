# Builds a VST3 around the Zig-built CLAP using clap-wrapper's "thin" pattern.
#
# The resulting OR120AmpSim.vst3 is a generic bridge that, when a VST3 host loads
# it, locates the same-named OR120AmpSim.clap in the CLAP folders and translates
# the VST3 protocol to CLAP. Install BOTH files together.
#
# Prerequisites: zig, cmake, git, and a C++ toolchain (MSVC on Windows). The
# first configure downloads the CLAP + VST3 SDKs via CPM, so network access is
# required once (and the download is sizeable).
#
# Run from the repo root:  pwsh -File scripts/build-vst3.ps1 [-Config Release]
param(
    [ValidateSet("Release", "Debug", "RelWithDebInfo")]
    [string]$Config = "Release"
)
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# 1. Make sure clap-wrapper is vendored.
$wrapper = Join-Path $root "vendor/clap-wrapper"
if (-not (Test-Path (Join-Path $wrapper "CMakeLists.txt"))) {
    Write-Host "clap-wrapper not vendored; running scripts/vendor.ps1..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "vendor.ps1")
}

# 2. Build the CLAP first — the VST3 loads it by name at runtime.
Write-Host "Building the CLAP (zig build)..." -ForegroundColor Cyan
zig build
if ($LASTEXITCODE -ne 0) { throw "zig build failed" }

# 3. Configure clap-wrapper as a standalone thin VST3 project.
#    CLAP_WRAPPER_OUTPUT_NAME sets both the .vst3 name and the .clap it loads.
$buildDir = Join-Path $root "build/vst3"
Write-Host "Configuring clap-wrapper (CMake, first run downloads SDKs)..." -ForegroundColor Cyan
cmake -B $buildDir -S $wrapper `
    -DCLAP_WRAPPER_OUTPUT_NAME=OR120AmpSim `
    -DCLAP_WRAPPER_DOWNLOAD_DEPENDENCIES=ON `
    -DCLAP_WRAPPER_BUILD_AAX=OFF `
    -DCMAKE_BUILD_TYPE=$Config
if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }

# 4. Build.
Write-Host "Building the VST3..." -ForegroundColor Cyan
cmake --build $buildDir --config $Config
if ($LASTEXITCODE -ne 0) { throw "cmake build failed" }

# 5. Collect the .vst3 alongside the .clap in zig-out.
$out = Join-Path $root "zig-out/vst3"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$vst3 = Get-ChildItem -Path $buildDir -Recurse -Filter "OR120AmpSim.vst3" -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $vst3) { throw "Could not locate a built OR120AmpSim.vst3 under $buildDir" }
$dest = Join-Path $out $vst3.Name
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
Copy-Item -Recurse -Force $vst3.FullName $dest

Write-Host "VST3 ready: $dest" -ForegroundColor Green
Write-Host "Install OR120AmpSim.vst3 and OR120AmpSim.clap together; the VST3 loads the CLAP by name." -ForegroundColor Yellow
