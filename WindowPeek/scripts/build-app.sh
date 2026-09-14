#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/windowpeek-bundle.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Window Peek.app"
DESTINATION="$ROOT/dist/Window Peek.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc Sources/WindowPeek/IconArtwork.swift scripts/IconBuilder/main.swift -o .build/icon-builder
.build/icon-builder "$ROOT/Assets"
iconutil -c icns "$ROOT/Assets/WindowPeek.iconset" -o "$APP/Contents/Resources/WindowPeek.icns"
cp "$BIN_DIR/WindowPeek" "$APP/Contents/MacOS/WindowPeek"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>WindowPeek</string>
  <key>CFBundleIdentifier</key><string>local.windowpeek.app</string>
  <key>CFBundleName</key><string>Window Peek</string>
  <key>CFBundleDisplayName</key><string>Window Peek</string>
  <key>CFBundleIconFile</key><string>WindowPeek.icns</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.2.1</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSScreenCaptureUsageDescription</key><string>在长按激活键时显示当前应用的窗口预览。画面仅在内存中使用，不保存或上传。</string>
</dict></plist>
PLIST
# Finder / synced folders may attach metadata that invalidates strict bundle verification.
xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$APP" 2>/dev/null || true
SIGN_IDENTITY="${WINDOWPEEK_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/"Developer ID Application:/ {print $2; exit}')}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
  printf 'No Developer ID identity found; using ad-hoc signing. Updates may require reauthorization.\n'
fi
codesign --force --sign "$SIGN_IDENTITY" --timestamp=none --identifier local.windowpeek.app "$APP"
codesign --verify --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
mkdir -p "$ROOT/dist"
if pgrep -f "$DESTINATION/Contents/MacOS/WindowPeek" >/dev/null; then
  printf 'Quit Window Peek before replacing the running application.\n' >&2
  exit 1
fi
if [[ -d "$DESTINATION" ]]; then mv "$DESTINATION" "$STAGING/previous.app"; fi
if ! mv "$APP" "$DESTINATION"; then
  if [[ -d "$STAGING/previous.app" ]]; then mv "$STAGING/previous.app" "$DESTINATION"; fi
  exit 1
fi
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DESTINATION"
printf '\nBuilt: %s\n' "$DESTINATION"
if [[ "${1:-}" == "--install" ]]; then
  INSTALL_ROOT="$HOME/Applications"
  INSTALLED_APP="$INSTALL_ROOT/Window Peek.app"
  mkdir -p "$INSTALL_ROOT"
  if pgrep -f "$INSTALLED_APP/Contents/MacOS/WindowPeek" >/dev/null; then
    printf 'Quit the installed Window Peek before updating it.\n' >&2
    exit 1
  fi
  if [[ -e "$INSTALLED_APP" ]]; then
    EXISTING_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$INSTALLED_APP/Contents/Info.plist")"
    [[ "$EXISTING_ID" == "local.windowpeek.app" ]] || { printf 'Refusing to replace a different application.\n' >&2; exit 1; }
  fi
  INSTALL_STAGING="$(mktemp -d "$INSTALL_ROOT/.windowpeek.XXXXXX")"
  trap 'rm -rf "$STAGING" "$INSTALL_STAGING"' EXIT
  ditto --norsrc --noextattr "$DESTINATION" "$INSTALL_STAGING/Window Peek.app"
  codesign --verify --strict "$INSTALL_STAGING/Window Peek.app"
  if [[ -d "$INSTALLED_APP" ]]; then mv "$INSTALLED_APP" "$INSTALL_STAGING/previous.app"; fi
  if ! mv "$INSTALL_STAGING/Window Peek.app" "$INSTALLED_APP"; then
    if [[ -d "$INSTALL_STAGING/previous.app" ]]; then mv "$INSTALL_STAGING/previous.app" "$INSTALLED_APP"; fi
    exit 1
  fi
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALLED_APP"
  codesign --verify --strict "$INSTALLED_APP"
  printf 'Installed: %s\n' "$INSTALLED_APP"
fi
