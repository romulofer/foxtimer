# FoxTimer

A simple cross-platform Pomodoro timer built with Flutter.

---

## Requirements

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.10 or later (tested on 3.48.0)
- Dart SDK ^3.9.2 (bundled with Flutter)
- For Linux builds: CMake ≥ 3.13, Ninja, GTK3 development libraries, `pkg-config`
- For packaging as `.deb`: `dpkg-deb` (standard on Debian/Ubuntu)

### Install Linux build dependencies (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y cmake ninja-build pkg-config \
  libgtk-3-dev libblkid-dev liblzma-dev
```

---

## Getting dependencies

```bash
flutter pub get
```

---

## Running in development

```bash
flutter run -d linux
```

---

## Building a release

### Linux

```bash
flutter build linux --release
```

The compiled bundle is placed at:

```
build/linux/x64/release/bundle/
├── foxtimer          # executable
├── lib/              # shared libraries
└── data/             # Flutter assets and ICU data
```

> The bundle directory is self-contained and relocatable as long as `data/` and `lib/` stay next to the binary.

### Other platforms

```bash
flutter build apk --release       # Android
flutter build ios --release       # iOS (macOS host required)
flutter build macos --release     # macOS
flutter build windows --release   # Windows
flutter build web --release       # Web
```

---

## Packaging as a .deb (Linux)

After running `flutter build linux --release`, use the script below to produce a Debian package. No extra tools beyond `dpkg-deb` are needed.

```bash
#!/bin/bash
set -e

BUNDLE="build/linux/x64/release/bundle"
VERSION="1.2.0"
ARCH="amd64"
DEB_ROOT="/tmp/foxtimer_deb"

# 1. Create package directory tree
rm -rf "$DEB_ROOT"
mkdir -p "$DEB_ROOT/usr/bin"
mkdir -p "$DEB_ROOT/usr/lib/foxtimer/lib"
mkdir -p "$DEB_ROOT/usr/lib/foxtimer/data"
mkdir -p "$DEB_ROOT/usr/share/applications"
mkdir -p "$DEB_ROOT/usr/share/pixmaps"
mkdir -p "$DEB_ROOT/DEBIAN"

# 2. Copy bundle contents
cp    "$BUNDLE/foxtimer"    "$DEB_ROOT/usr/lib/foxtimer/foxtimer"
chmod 755                   "$DEB_ROOT/usr/lib/foxtimer/foxtimer"
cp -r "$BUNDLE/lib/."       "$DEB_ROOT/usr/lib/foxtimer/lib/"
cp -r "$BUNDLE/data/."      "$DEB_ROOT/usr/lib/foxtimer/data/"

# 3. Launcher wrapper (ensures correct working directory for relative paths)
cat > "$DEB_ROOT/usr/bin/foxtimer" << 'EOF'
#!/bin/sh
cd /usr/lib/foxtimer
exec ./foxtimer "$@"
EOF
chmod 755 "$DEB_ROOT/usr/bin/foxtimer"

# 4. Desktop entry
cat > "$DEB_ROOT/usr/share/applications/foxtimer.desktop" << 'EOF'
[Desktop Entry]
Name=FoxTimer
Comment=A Simple Pomodoro App
Exec=foxtimer
Icon=foxtimer
Terminal=false
Type=Application
Categories=Utility;
EOF

# 5. App icon
cp icon.png "$DEB_ROOT/usr/share/pixmaps/foxtimer.png"

# 6. DEBIAN/control
INSTALLED_SIZE=$(du -sk "$DEB_ROOT" | cut -f1)
cat > "$DEB_ROOT/DEBIAN/control" << EOF
Package: foxtimer
Version: $VERSION
Architecture: $ARCH
Maintainer: Romulo
Installed-Size: $INSTALLED_SIZE
Depends: libgtk-3-0, libblkid1, liblzma5
Section: utils
Priority: optional
Description: FoxTimer - A Simple Pomodoro App
 A cross-platform Pomodoro timer application built with Flutter.
EOF

# 7. Build the package
dpkg-deb --build --root-owner-group "$DEB_ROOT" \
  "foxtimer_${VERSION}_${ARCH}.deb"

echo "Done: foxtimer_${VERSION}_${ARCH}.deb"
```

Run it from the project root:

```bash
bash package_deb.sh
```

### Installing the .deb

```bash
sudo dpkg -i foxtimer_1.2.0_amd64.deb
# Fix any missing dependencies:
sudo apt-get install -f
```

### Uninstalling

```bash
sudo dpkg -r foxtimer
```

---

## Project structure

```
foxtimer/
├── lib/               # Dart source code
├── assets/            # Bundled assets (sounds, etc.)
├── linux/             # Linux-specific CMake build files
├── android/           # Android platform code
├── ios/               # iOS platform code
├── macos/             # macOS platform code
├── windows/           # Windows platform code
├── web/               # Web platform code
├── test/              # Unit tests
├── integration_test/  # Integration tests
└── pubspec.yaml       # Project manifest and dependencies
```

---

## Resources

- [Flutter documentation](https://docs.flutter.dev/)
- [Flutter Linux desktop support](https://docs.flutter.dev/platform-integration/linux/building)
- [Dart packages (pub.dev)](https://pub.dev/)
