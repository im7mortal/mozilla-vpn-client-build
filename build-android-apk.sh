#!/bin/bash
#
# Build script for Mozilla VPN Android APK using Docker
# This script builds a Docker image and runs the complete build process
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
MOZILLA_VPN_DIR="$PROJECT_ROOT/mozilla-vpn-client"
RELEASE_DIR="$PROJECT_ROOT/release"
DOCKER_IMAGE_NAME="mozilla-vpn-android-builder"
DOCKER_CONTAINER_NAME="mozilla-vpn-android-build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if mozilla-vpn-client directory exists
if [ ! -d "$MOZILLA_VPN_DIR" ]; then
    print_error "mozilla-vpn-client directory not found at $MOZILLA_VPN_DIR"
    exit 1
fi

# Determine build type (debug or release)
BUILD_TYPE="${1:-debug}"
if [ "$BUILD_TYPE" != "debug" ] && [ "$BUILD_TYPE" != "release" ]; then
    print_error "Invalid build type: $BUILD_TYPE (must be 'debug' or 'release')"
    exit 1
fi

print_info "Build type: $BUILD_TYPE"

# Clean up old container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^${DOCKER_CONTAINER_NAME}$"; then
    print_info "Removing old container..."
    docker rm -f "$DOCKER_CONTAINER_NAME" > /dev/null 2>&1 || true
fi

# Build Docker image
print_info "Building Docker image: $DOCKER_IMAGE_NAME"
docker build -f "$PROJECT_ROOT/Dockerfile.android" -t "$DOCKER_IMAGE_NAME" "$PROJECT_ROOT" || {
    print_error "Failed to build Docker image"
    exit 1
}

# Create release directory
mkdir -p "$RELEASE_DIR"
print_info "Output directory: $RELEASE_DIR"

# Run build in container (non-interactive)
print_info "Starting build in Docker container..."
print_info "This may take a while..."

docker run --rm \
    --name "$DOCKER_CONTAINER_NAME" \
    -v "$MOZILLA_VPN_DIR:/build/mozilla-vpn-client" \
    -v "$RELEASE_DIR:/output" \
    -e QT_VERSION="${QT_VERSION:-6.9.3}" \
    -e ANDROID_ARCH="${ANDROID_ARCH:-android_arm64_v8a}" \
    -e BUILD_TYPE="$BUILD_TYPE" \
    -e ADJUST_TOKEN="${ADJUST_TOKEN:-}" \
    "$DOCKER_IMAGE_NAME" \
    /build/docker-build.sh || {
    print_error "Build failed!"
    exit 1
}

# Check for APK in release directory
APK_COUNT=$(ls -1 "$RELEASE_DIR"/*.apk 2>/dev/null | wc -l)
if [ "$APK_COUNT" -gt 0 ]; then
    print_info "Build completed successfully!"
    echo ""
    print_info "APKs in release directory:"
    ls -lh "$RELEASE_DIR"/*.apk
else
    print_warn "No APK found in release directory. Check build logs above for errors."
    exit 1
fi
