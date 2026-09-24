#!/bin/bash
set -e

# Build a Debian package from the release Linux bundle.
# Run `flutter build linux --release` first, then run this from the project root.

BUNDLE="build/linux/x64/release/bundle"
VERSION="1.3.3"
ARCH="amd64"
# Must match APPLICATION_ID in linux/CMakeLists.txt. The desktop file, the
# themed icon and StartupWMClass are all named after it so the desktop
# environment can map the running window (WM_CLASS / Wayland app-id) back to
# this .desktop entry — otherwise the taskbar and alt-tab show no icon.
APP_ID="com.example.foxtimer"
DEB_ROOT="/tmp/foxtimer_deb"

# 1. Create package directory tree
rm -rf "$DEB_ROOT"
mkdir -p "$DEB_ROOT/usr/bin"
mkdir -p "$DEB_ROOT/usr/lib/foxtimer/lib"
mkdir -p "$DEB_ROOT/usr/lib/foxtimer/data"
mkdir -p "$DEB_ROOT/usr/share/applications"
mkdir -p "$DEB_ROOT/usr/share/pixmaps"
mkdir -p "$DEB_ROOT/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$DEB_ROOT/usr/share/icons/hicolor/512x512/apps"
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

# 4. Desktop entry — filename, Icon and StartupWMClass all match APP_ID so the
#    window switcher and taskbar can associate the window with this entry.
cat > "$DEB_ROOT/usr/share/applications/${APP_ID}.desktop" << EOF
[Desktop Entry]
Name=FoxTimer
Comment=A Simple Pomodoro App
Exec=foxtimer
Icon=${APP_ID}
Terminal=false
Type=Application
Categories=Utility;
StartupWMClass=${APP_ID}
EOF

# 5. App icon — install into the hicolor theme (named after APP_ID) so the
#    desktop environment finds it via the Icon= key, with a pixmaps fallback.
convert icon.png -resize 256x256 "$DEB_ROOT/usr/share/icons/hicolor/256x256/apps/${APP_ID}.png"
convert icon.png -resize 512x512 "$DEB_ROOT/usr/share/icons/hicolor/512x512/apps/${APP_ID}.png"
cp "$DEB_ROOT/usr/share/icons/hicolor/256x256/apps/${APP_ID}.png" \
   "$DEB_ROOT/usr/share/pixmaps/${APP_ID}.png"

# 6. Maintainer scripts to refresh icon and desktop caches after install/remove.
cat > "$DEB_ROOT/DEBIAN/postinst" << 'EOF'
#!/bin/sh
set -e
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi
EOF
chmod 755 "$DEB_ROOT/DEBIAN/postinst"
cp "$DEB_ROOT/DEBIAN/postinst" "$DEB_ROOT/DEBIAN/postrm"

# 7. DEBIAN/control
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

# 8. Build the package
dpkg-deb --build --root-owner-group "$DEB_ROOT" \
  "foxtimer_${VERSION}_${ARCH}.deb"

echo "Done: foxtimer_${VERSION}_${ARCH}.deb"
