#!/bin/bash
#
# Build script that runs inside Docker container
# This script executes the complete Mozilla VPN Android build process
#

set -e

# Activate conda environment
source /opt/conda/etc/profile.d/conda.sh
conda activate vpn-android

# Source conda activation scripts to get Android and Qt environment variables
# These scripts are created by conda_setup_sdk.sh and conda_setup_qt.sh
if [ -f "$CONDA_PREFIX/etc/conda/activate.d/vpn_android_sdk.sh" ]; then
    source "$CONDA_PREFIX/etc/conda/activate.d/vpn_android_sdk.sh"
fi
if [ -f "$CONDA_PREFIX/etc/conda/activate.d/vpn_android_qt.sh" ]; then
    source "$CONDA_PREFIX/etc/conda/activate.d/vpn_android_qt.sh"
fi

# Set up Qt paths from conda environment (if not already set by activation script)
export QT_VERSION=${QT_VERSION:-6.9.3}
export ANDROID_ARCH=${ANDROID_ARCH:-android_arm64_v8a}
if [ -z "$QTPATH" ]; then
    export QT_DIR=$CONDA_PREFIX/Qt
    export QTPATH=$QT_DIR/$QT_VERSION/$ANDROID_ARCH
    export QT_HOST_PATH=$QT_DIR/$QT_VERSION/gcc_64
fi

# Verify Qt is installed
if [ ! -f "$QTPATH/bin/qt-cmake" ]; then
    echo "ERROR: Qt not found at $QTPATH/bin/qt-cmake"
    echo "Qt should have been installed during Docker image build."
    exit 1
fi

# Ensure Android environment variables are set (from conda activation scripts)
if [ -z "${ANDROID_SDK_ROOT}" ]; then
    export ANDROID_SDK_ROOT=$CONDA_PREFIX/android_home
fi
if [ -z "${ANDROID_NDK_ROOT}" ]; then
    # Find NDK version from installed packages
    if [ -d "$CONDA_PREFIX/android_home/ndk" ]; then
        NDK_VERSION=$(ls -1 $CONDA_PREFIX/android_home/ndk | head -1)
        export ANDROID_NDK_ROOT=$CONDA_PREFIX/android_home/ndk/$NDK_VERSION
    else
        echo "ERROR: Android NDK not found"
        exit 1
    fi
fi

# Fix git safe directory issue
git config --global --add safe.directory /build/mozilla-vpn-client || true

# Change to source directory
cd /build/mozilla-vpn-client

# Determine build type from environment variable or default to debug
BUILD_TYPE=${BUILD_TYPE:-debug}
BUILD_ARGS="-d"
if [ "$BUILD_TYPE" = "release" ]; then
    BUILD_ARGS=""
    if [ -n "$ADJUST_TOKEN" ]; then
        BUILD_ARGS="--adjusttoken $ADJUST_TOKEN"
    fi
fi

echo "=========================================="
echo "Building Mozilla VPN Android APK"
echo "Build type: $BUILD_TYPE"
echo "Qt path: $QTPATH"
echo "Android SDK: $ANDROID_SDK_ROOT"
echo "Android NDK: $ANDROID_NDK_ROOT"
echo "=========================================="

# Run the build
./scripts/android/cmake.sh "$QTPATH" $BUILD_ARGS

# Find and copy APK to output directory
if [ "$BUILD_TYPE" = "release" ]; then
    APK_DIR=".tmp/src/android-build/build/outputs/apk/release"
else
    APK_DIR=".tmp/src/android-build/build/outputs/apk/debug"
fi

if [ -d "$APK_DIR" ]; then
    APK_COUNT=$(find "$APK_DIR" -name "*.apk" 2>/dev/null | wc -l)
    if [ "$APK_COUNT" -gt 0 ]; then
        echo ""
        echo "=========================================="
        echo "Build completed successfully!"
        echo "APK files found:"
        find "$APK_DIR" -name "*.apk" 2>/dev/null | while read -r apk; do
            echo "  - $apk"
            cp "$apk" /output/
            echo "    -> Copied to /output/$(basename $apk)"
        done
        echo "=========================================="
    else
        echo "ERROR: Build completed but no APK files found in $APK_DIR"
        exit 1
    fi
else
    echo "ERROR: Build directory not found: $APK_DIR"
    exit 1
fi

