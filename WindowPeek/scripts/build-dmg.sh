#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIGN_IDENTITY="${WINDOWPEEK_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/"Developer ID Application:/ {print $2; exit}')}"
[[ -n "$SIGN_IDENTITY" && "$SIGN_IDENTITY" != "-" ]] || { printf 'A Developer ID Application identity is required.\n' >&2; exit 1; }
WINDOWPEEK_SIGN_IDENTITY="$SIGN_IDENTITY" "$ROOT/scripts/build-app.sh"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/windowpeek-dmg.XXXXXX")"
MOUNT="$STAGING/mount"
MOUNTED=false
cleanup() {
  if [[ "$MOUNTED" == true ]]; then hdiutil detach "$MOUNT" >/dev/null || return; fi
  rm -rf "$STAGING"
}
trap cleanup EXIT
mkdir -p "$STAGING/content" "$MOUNT"
APP="$STAGING/content/Window Peek.app"
ditto --norsrc --noextattr "$ROOT/dist/Window Peek.app" "$APP"
"$ROOT/scripts/sign-bundle.sh" "$APP" "$SIGN_IDENTITY" --timestamp
codesign --verify --deep --strict "$APP"
ln -s /Applications "$STAGING/content/Applications"
mkdir -p "$STAGING/content/.background"
swiftc "$ROOT/scripts/DMGArtwork/main.swift" -o "$STAGING/dmg-artwork"
"$STAGING/dmg-artwork" "$STAGING/content/.background/installer.png"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ARCH="$(lipo -archs "$APP/Contents/MacOS/WindowPeek" | tr ' ' '-')"
NAME="WindowPeek-$VERSION-$ARCH-Installer.dmg"
hdiutil create -volname 'Window Peek' -srcfolder "$STAGING/content" -format UDRW -fs HFS+ "$STAGING/layout.dmg"
hdiutil attach "$STAGING/layout.dmg" -nobrowse -mountpoint "$MOUNT"
MOUNTED=true
PYTHON="$ROOT/.build/dmg-tools/bin/python"
if [[ ! -x "$PYTHON" ]]; then python3 -m venv "$ROOT/.build/dmg-tools"; fi
if ! "$PYTHON" -c 'import ds_store, mac_alias' 2>/dev/null; then
  "$PYTHON" -m pip install 'ds-store==1.3.3' 'mac-alias==2.2.3'
fi
"$PYTHON" "$ROOT/scripts/layout-dmg.py" "$MOUNT"
[[ -s "$MOUNT/.DS_Store" ]]
sync
hdiutil detach "$MOUNT"
MOUNTED=false
hdiutil convert "$STAGING/layout.dmg" -format UDZO -o "$STAGING/$NAME"
codesign --sign "$SIGN_IDENTITY" --timestamp "$STAGING/$NAME"
codesign --verify --strict "$STAGING/$NAME"
hdiutil verify "$STAGING/$NAME"
hdiutil attach "$STAGING/$NAME" -readonly -nobrowse -mountpoint "$MOUNT"
MOUNTED=true
codesign --verify --deep --strict "$MOUNT/Window Peek.app"
[[ ! -e "$MOUNT/安装说明.txt" && -s "$MOUNT/.DS_Store" && -s "$MOUNT/.background/installer.png" ]]
[[ "$(readlink "$MOUNT/Applications")" == /Applications ]]
cmp "$APP/Contents/MacOS/WindowPeek" "$MOUNT/Window Peek.app/Contents/MacOS/WindowPeek"
hdiutil detach "$MOUNT"
MOUNTED=false
mv "$STAGING/$NAME" "$ROOT/dist/$NAME"
(cd "$ROOT/dist" && shasum -a 256 "$NAME" > "$NAME.sha256")
printf '\nDMG: %s\n' "$ROOT/dist/$NAME"
