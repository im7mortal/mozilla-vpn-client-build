# Android APK Build Requirements

This document describes exactly what's needed to build the Mozilla VPN Android APK.

## Overview

The build process uses Docker to create a reproducible build environment with all dependencies. The build can be run:
- **Locally**: Using Docker on your machine
- **CI/CD**: Using GitHub Actions (automated)

## Prerequisites

### For Local Build

1. **Docker** (required)
   - Install Docker: https://docs.docker.com/get-docker/
   - Ensure Docker daemon is running

2. **Git** (required)
   - To clone the repository and submodules

3. **Disk Space** (recommended: 20GB+)
   - Docker image: ~10-15GB
   - Build artifacts: ~5GB
   - Qt downloads: ~2GB

### For GitHub Actions

- No prerequisites needed - everything runs in GitHub's runners
- Uses GitHub Actions' built-in Docker support

## Required Files

The build system requires these files in the repository:

### Root Directory Files
- `Dockerfile.android` - Docker image definition
- `docker-build.sh` - Build script that runs inside Docker container
- `build-android-apk.sh` - Main build script for local use

### mozilla-vpn-client Directory Files
The `mozilla-vpn-client` directory (or submodule) must contain:

**Configuration Files:**
- `env-android.yml` - Conda environment definition
- `requirements.txt` - Python dependencies
- `taskcluster/scripts/requirements.txt` - Additional Python dependencies
- `android_sdk.txt` - Android SDK version specification

**Build Scripts:**
- `scripts/android/conda_setup_sdk.sh` - Android SDK setup script
- `scripts/android/conda_setup_qt.sh` - Qt setup script
- `scripts/android/cmake.sh` - Main CMake build script

**Source Code:**
- All Android source code in `android/` directory
- All C++/QML source code in `src/` directory
- All other required source files

## Build Dependencies (Installed Automatically)

The Docker image automatically installs:

### System Packages
- build-essential
- git, wget, unzip, curl
- protobuf-compiler

### Conda Environment (`vpn-android`)
- Python 3.9
- Rust 1.75 (with Android targets)
- Go 1.24.5
- CMake 3.31.6
- Ninja 1.11.0
- OpenJDK 17
- ccache 4.10.1

### Android SDK/NDK
- Installed via `conda_setup_sdk.sh`
- Version specified in `android_sdk.txt`
- NDK version: 27.2.12479018 (or latest from android_sdk.txt)

### Qt Framework
- Qt 6.9.3 (required for Android builds)
- Android architecture: `android_arm64_v8a` (default)
- Downloaded and installed via `conda_setup_qt.sh`

### Python Packages
- From `requirements.txt`
- From `taskcluster/scripts/requirements.txt`

## Environment Variables

### Build Configuration
- `QT_VERSION` - Qt version (default: 6.9.3)
- `ANDROID_ARCH` - Android architecture (default: android_arm64_v8a)
- `BUILD_TYPE` - Build type: `debug` or `release` (default: debug)
- `ADJUST_TOKEN` - Adjust SDK token for release builds (optional)

### Example
```bash
QT_VERSION=6.9.3 ANDROID_ARCH=android_arm64_v8a BUILD_TYPE=debug ./build-android-apk.sh
```

## Build Process

### Step 1: Docker Image Build
1. Creates base image from `continuumio/miniconda3:latest`
2. Installs system dependencies
3. Creates conda environment from `env-android.yml`
4. Sets up Android SDK/NDK
5. Downloads and installs Qt 6.9.3
6. Copies build scripts

**Time**: 30-60 minutes (first time, includes Qt download)
**Time**: 5-10 minutes (subsequent builds, uses cache)

### Step 2: APK Build
1. Mounts `mozilla-vpn-client` directory into container
2. Activates conda environment
3. Runs CMake configuration
4. Compiles C++/Rust/Go code
5. Builds Android APK with Gradle
6. Copies APK to `release/` directory

**Time**: 10-30 minutes (depending on CPU and cache)

## Output

APK files are generated in the `release/` directory:
- `android-build-universal-debug.apk` - Universal APK (all architectures)
- `android-build-arm64-v8a-debug.apk` - ARM64 only
- `android-build-armeabi-v7a-debug.apk` - ARMv7 only
- `android-build-x86-debug.apk` - x86 only
- `android-build-x86_64-debug.apk` - x86_64 only

For release builds, replace `debug` with `release`.

## Network Requirements

The build process downloads:
- Qt 6.9.3 (~2GB) - from Qt mirrors
- Android SDK/NDK (~1GB) - from Google
- Python packages (~100MB) - from PyPI
- Rust crates (~500MB) - from crates.io
- Gradle dependencies (~200MB) - from Maven repositories

**Total**: ~4GB of downloads (first time only)

## Troubleshooting

### Network Timeouts
If downloads timeout, retry the build. The Docker build system caches layers, so retries are faster.

### Qt Version Mismatch
Ensure `QT_VERSION` in `Dockerfile.android` matches the requirement in `mozilla-vpn-client/scripts/cmake/check_qt_breakage.cmake` (currently 6.9.0+).

### Out of Disk Space
- Clean Docker: `docker system prune -a`
- Remove old images: `docker image prune -a`

### Build Fails
- Check Docker logs: `docker logs <container-name>`
- Verify all required files exist
- Ensure `mozilla-vpn-client` directory is complete

## Local Build Command

```bash
# Debug build (default)
./build-android-apk.sh debug

# Release build
./build-android-apk.sh release

# With custom Qt version
QT_VERSION=6.9.3 ./build-android-apk.sh debug
```

## GitHub Actions

See `.github/workflows/build-android-apk.yml` for automated builds.

