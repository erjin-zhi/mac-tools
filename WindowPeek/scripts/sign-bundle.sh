#!/bin/bash
set -euo pipefail
APP="${1:?Pass app bundle}"
SIGN_IDENTITY="${2:?Pass code signing identity}"
TIMESTAMP="${3:---timestamp=none}"
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
# Sign nested code inside-out; preserve Sparkle's framework symlinks.
if [[ -d "$FRAMEWORK" ]]; then
  while IFS= read -r -d '' child; do
    codesign --force --sign "$SIGN_IDENTITY" --options runtime "$TIMESTAMP" "$child"
  done < <(find "$FRAMEWORK/Versions" -type d \( -name '*.xpc' -o -name '*.app' \) -print0)
  codesign --force --sign "$SIGN_IDENTITY" --options runtime "$TIMESTAMP" "$FRAMEWORK/Versions/B/Autoupdate"
  codesign --force --sign "$SIGN_IDENTITY" --options runtime "$TIMESTAMP" "$FRAMEWORK"
fi
codesign --force --sign "$SIGN_IDENTITY" --options runtime "$TIMESTAMP" --identifier local.windowpeek.app "$APP"
codesign --verify --deep --strict "$APP"
