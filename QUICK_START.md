# Quick Start: Building Android APK

## Local Build (Docker)

### Prerequisites
- Docker installed and running
- `mozilla-vpn-client` directory (or submodule) in project root

### Build Command

```bash
# Debug build (default)
./build-android-apk.sh debug

# Release build
./build-android-apk.sh release
```

### Output
APK files will be in the `release/` directory:
- `android-build-universal-debug.apk` - Universal APK (recommended)

### First Build
- Takes 30-60 minutes (downloads Qt, Android SDK, etc.)
- Subsequent builds: 10-30 minutes

## GitHub Actions

### Manual Trigger
1. Go to **Actions** tab in GitHub
2. Select **Build Android APK** workflow
3. Click **Run workflow**
4. Choose build type (debug/release)
5. Click **Run workflow**

### Automatic Trigger
- Runs on push to `main`, `master`, or `working` branches
- Runs on pull requests to these branches
- Only when files in `mozilla-vpn-client/` or build scripts change

### Download APK
1. Go to **Actions** tab
2. Click on the completed workflow run
3. Download **android-apk-debug** (or **android-apk-release**) artifact

## Customization

### Environment Variables
```bash
# Custom Qt version
QT_VERSION=6.9.3 ./build-android-apk.sh debug

# Custom Android architecture
ANDROID_ARCH=android_armeabi_v7a ./build-android-apk.sh debug

# Release with Adjust token
ADJUST_TOKEN=your_token ./build-android-apk.sh release
```

## Troubleshooting

### Docker not found
```bash
# Install Docker: https://docs.docker.com/get-docker/
# Verify installation:
docker --version
```

### Network timeouts
- Retry the build (Docker caches downloads)
- Check internet connection
- Qt downloads can be slow (~2GB)

### Out of disk space
```bash
# Clean Docker cache
docker system prune -a
```

## More Information

- **Detailed Requirements**: See `BUILD_REQUIREMENTS.md`
- **Full Guide**: See `BUILD_ANDROID_README.md`
- **GitHub Actions**: See `.github/workflows/build-android-apk.yml`

