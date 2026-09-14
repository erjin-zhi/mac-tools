#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --chrome ) ]]; then
  printf 'Usage: verify-previews.sh [--chrome]\n' >&2
  exit 1
fi
swift build --package-path "$ROOT"
BIN_DIR="$(swift build --package-path "$ROOT" --show-bin-path)"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/windowpeek-preview-check.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
swiftc -parse-as-library -I "$BIN_DIR/Modules" "$BIN_DIR"/SwitcherCore.build/*.swift.o \
  "$ROOT/Sources/WindowPeek/WindowService.swift" \
  "$ROOT/Sources/WindowPeek/WindowIdentityBridge.swift" \
  "$ROOT/Sources/WindowPeek/SwitcherUI.swift" \
  "$ROOT/Sources/WindowPeek/DemoImage.swift" \
  "$ROOT/scripts/PreviewCheck/main.swift" -o "$STAGING/PreviewCheck"
"$STAGING/PreviewCheck" "$@"
