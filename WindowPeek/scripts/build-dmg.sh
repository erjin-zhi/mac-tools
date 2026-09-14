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
codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp --identifier local.windowpeek.app "$APP"
codesign --verify --deep --strict "$APP"
ln -s /Applications "$STAGING/content/Applications"
cat > "$STAGING/content/安装说明.txt" <<'TEXT'
Window Peek

将 Window Peek.app 拖到 Applications，安装后从应用程序打开。
更新前请先从菜单栏退出旧版本；如果原来安装在用户目录 ~/Applications，
请替换原位置的版本，避免保留多个副本。不要直接从磁盘映像运行。

需要 macOS 14 或更新版本，Apple Silicon 芯片。
首次使用请在系统设置中开启辅助功能和录屏权限，随后重新启动应用。
默认长按 Command 显示窗口预览，按数字选择，松开切换。

此安装包使用 Developer ID 证书签名，Apple 公证状态请查看下载页的发布说明。
TEXT
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ARCH="$(lipo -archs "$APP/Contents/MacOS/WindowPeek" | tr ' ' '-')"
NAME="WindowPeek-$VERSION-$ARCH.dmg"
hdiutil create -volname 'Window Peek' -srcfolder "$STAGING/content" -format UDZO -fs HFS+ "$STAGING/$NAME"
codesign --sign "$SIGN_IDENTITY" --timestamp "$STAGING/$NAME"
codesign --verify --strict "$STAGING/$NAME"
hdiutil verify "$STAGING/$NAME"
hdiutil attach "$STAGING/$NAME" -readonly -nobrowse -mountpoint "$MOUNT"
MOUNTED=true
codesign --verify --deep --strict "$MOUNT/Window Peek.app"
[[ "$(readlink "$MOUNT/Applications")" == /Applications ]]
cmp "$APP/Contents/MacOS/WindowPeek" "$MOUNT/Window Peek.app/Contents/MacOS/WindowPeek"
hdiutil detach "$MOUNT"
MOUNTED=false
mv "$STAGING/$NAME" "$ROOT/dist/$NAME"
(cd "$ROOT/dist" && shasum -a 256 "$NAME" > "$NAME.sha256")
printf '\nDMG: %s\n' "$ROOT/dist/$NAME"
