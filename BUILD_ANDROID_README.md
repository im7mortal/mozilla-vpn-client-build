# Android APK Build Guide

This directory contains Docker-based build tools for creating Mozilla VPN Android APKs.

## Files

- `Dockerfile.android` - Docker image with all build dependencies (Conda, Android SDK/NDK, etc.)
- `build-android-apk.sh` - Build script that creates the Docker image and builds the APK
- `docker-build.sh` - Build script that runs inside the Docker container
- `BUILD_REQUIREMENTS.md` - Detailed documentation of all requirements
- `.github/workflows/build-android-apk.yml` - GitHub Actions workflow for automated builds

## Prerequisites

- Docker installed and running
- `mozilla-vpn-client` directory in the project root

## Usage

### Build Debug APK (default)

```bash
./build-android-apk.sh debug
```

or simply:

```bash
./build-android-apk.sh
```

### Build Release APK

```bash
./build-android-apk.sh release
```

For release builds, you can optionally provide an Adjust SDK token:

```bash
ADJUST_TOKEN=your_token_here ./build-android-apk.sh release
```

## Output

The generated APK(s) will be placed in the `release/` directory:

- Debug APKs: `release/android-build-arm64-v8a-debug.apk` (and other architectures)
- Release APKs: `release/android-build-arm64-v8a-release.apk` (and other architectures)

## Build Process

1. **Docker Image Build**: First run will build the Docker image (takes several minutes)
2. **Qt Installation**: First run will download and install Qt (takes 10-20 minutes)
3. **CMake Build**: Compiles the native C++ code
4. **Gradle Build**: Compiles Java/Kotlin code and packages the APK

## Environment Variables

You can customize the build with these environment variables:

- `QT_VERSION` - Qt version to use (default: 6.9.3, required: 6.9.0+)
- `ANDROID_ARCH` - Android architecture (default: android_arm64_v8a)
- `ADJUST_TOKEN` - Adjust SDK token for release builds

Example:

```bash
QT_VERSION=6.9.3 ANDROID_ARCH=android_armeabi_v7a ./build-android-apk.sh debug
```

## Troubleshooting

### Docker permission errors

If you get permission errors, ensure your user is in the docker group:

```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### Build fails with Qt errors

The first build will download Qt which can take a while. Ensure you have:
- Stable internet connection
- At least 10GB free disk space

### APK not found

If the build completes but no APK is found:
- Check the build logs for errors
- Verify the build completed successfully
- Check that the `.tmp/src/android-build/build/outputs/apk/` directory exists in the container

## Notes

- The Docker image is large (~5-10GB) and takes time to build initially
- Qt installation happens on first container run, not during image build
- The source code is mounted as a volume, so changes to code don't require rebuilding the image
- Build artifacts are created in `mozilla-vpn-client/.tmp/` directory








