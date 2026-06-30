# vendor-win.ps1 — fetch the engine binaries Crisp ships on Windows, into
# apps/desktop-win/.vendor/bin. The Windows port of apps/desktop/Scripts/vendor.sh.
#
# Crisp drives ffmpeg / ffprobe / whisper-cli / python as subprocesses. To make a
# downloaded build self-contained (no system ffmpeg/python required), the packaging
# step bundles these beside the .exe under engine/bin and the app resolves them from
# CRISP_FFMPEG/FFPROBE/WHISPER/PYTHON (set to the bundled paths). This produces that
# binary tree.
#
# Everything is PINNED + hash-checked. ffmpeg/ffprobe + python are downloaded;
# whisper-cli is built from a pinned whisper.cpp tag (no stable official Windows CLI
# binary is published) — that needs CMake + a C++ toolchain (Visual Studio Build
# Tools; the windows-latest CI runner ships them). x86_64 only.
#
# Re-running is cheap: anything already staged in .vendor/bin is left alone.
# Pass -Clean to rebuild from scratch.
param([switch]$Clean)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")   # → apps/desktop-win

$Vendor = Join-Path $PWD ".vendor"
$DL  = Join-Path $Vendor "dl"
$BIN = Join-Path $Vendor "bin"

if ($Clean) { Remove-Item -Recurse -Force $Vendor -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $DL, $BIN | Out-Null

# ---- Pinned sources -------------------------------------------------------
# ffmpeg/ffprobe: gyan.dev essentials build (GPL — matches Crisp's licence).
$FFMPEG_URL = "https://www.gyan.dev/ffmpeg/builds/packages/ffmpeg-8.1.2-essentials_build.zip"
$FFMPEG_SHA = "db580001caa24ac104c8cb856cd113a87b0a443f7bdf47d8c12b1d740584a2ec"
# python-build-standalone (same release tag as the macOS vendor; win64 stripped runtime).
$PY_URL = "https://github.com/astral-sh/python-build-standalone/releases/download/20260610/cpython-3.13.14+20260610-x86_64-pc-windows-msvc-install_only_stripped.tar.gz"
$PY_SHA = "2933d50847057b9131ff89578a220b9206c40fd6bc34d0c12afb716bd9bf8fc9"
$WHISPER_TAG = "v1.9.0"

function Verify($file, $sha) {
    $got = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower()
    if ($got -ne $sha.ToLower()) {
        Write-Error "checksum mismatch: $file`n    expected $sha`n    got      $got"
        exit 1
    }
}

function Fetch($url, $out, $sha) {
    if (-not (Test-Path $out)) {
        Write-Host "  v $(Split-Path $out -Leaf)"
        Invoke-WebRequest -Uri $url -OutFile $out
    }
    Verify $out $sha
}

# ---- ffmpeg + ffprobe (one essentials zip → bin/*.exe) --------------------
if (-not (Test-Path (Join-Path $BIN "ffmpeg.exe"))) {
    Fetch $FFMPEG_URL (Join-Path $DL "ffmpeg.zip") $FFMPEG_SHA
    $x = Join-Path $DL "ffmpeg_x"
    Remove-Item -Recurse -Force $x -ErrorAction SilentlyContinue
    Expand-Archive -Force (Join-Path $DL "ffmpeg.zip") $x
    $srcBin = Join-Path (Get-ChildItem $x -Directory | Select-Object -First 1).FullName "bin"
    Copy-Item (Join-Path $srcBin "ffmpeg.exe")  (Join-Path $BIN "ffmpeg.exe")  -Force
    Copy-Item (Join-Path $srcBin "ffprobe.exe") (Join-Path $BIN "ffprobe.exe") -Force
}

# ---- python (stdlib-only runtime → bin/python/python.exe) -----------------
if (-not (Test-Path (Join-Path $BIN "python/python.exe"))) {
    Fetch $PY_URL (Join-Path $DL "python.tar.gz") $PY_SHA
    Remove-Item -Recurse -Force (Join-Path $DL "python"), (Join-Path $BIN "python") -ErrorAction SilentlyContinue
    tar xzf (Join-Path $DL "python.tar.gz") -C $DL   # → $DL/python (bsdtar ships with Windows 10+)
    # Trim what a stdlib-only engine never touches (pip/idle/tk/tests).
    $pylib = Join-Path $DL "python/Lib"
    foreach ($d in "test", "idlelib", "turtledemo", "tkinter", "ensurepip", "lib2to3") {
        Remove-Item -Recurse -Force (Join-Path $pylib $d) -ErrorAction SilentlyContinue
    }
    Move-Item (Join-Path $DL "python") (Join-Path $BIN "python")
}

# ---- whisper-cli (built from a pinned tag) --------------------------------
if (-not (Test-Path (Join-Path $BIN "whisper-cli.exe"))) {
    if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
        Write-Error "CMake is required to build whisper-cli — install Visual Studio Build Tools + CMake."
        exit 1
    }
    $src = Join-Path $DL "whisper.cpp"
    if (-not (Test-Path $src)) {
        git clone --depth 1 --branch $WHISPER_TAG https://github.com/ggml-org/whisper.cpp $src
    }
    cmake -S $src -B (Join-Path $src "build") -DCMAKE_BUILD_TYPE=Release `
        -DBUILD_SHARED_LIBS=OFF -DWHISPER_BUILD_TESTS=OFF `
        -DWHISPER_BUILD_EXAMPLES=ON -DWHISPER_BUILD_SERVER=OFF
    cmake --build (Join-Path $src "build") --config Release --target whisper-cli
    # MSVC drops the exe under build/bin/Release/.
    $built = Get-ChildItem (Join-Path $src "build") -Recurse -Filter "whisper-cli.exe" | Select-Object -First 1
    Copy-Item $built.FullName (Join-Path $BIN "whisper-cli.exe") -Force
}

Write-Host "OK  Vendored engine binaries -> $BIN"
Get-ChildItem $BIN | ForEach-Object { Write-Host "    $($_.Name)" }
