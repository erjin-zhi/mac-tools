#!/bin/bash
set -euo pipefail
PROFILE="${1:?Usage: notarize-dmg.sh KEYCHAIN_PROFILE DMG_PATH [SUBMISSION_ID]}"
DMG="${2:?Pass the exact DMG path to notarize}"
[[ -f "$DMG" ]] || { printf 'DMG not found: %s\n' "$DMG" >&2; exit 1; }
codesign --verify --strict "$DMG"
SUBMISSION_ID="${3:-}"
if [[ -z "$SUBMISSION_ID" ]]; then
  # Save the ID before waiting: JSON output with submit --wait is buffered until completion.
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --output-format json > "$DMG.submission.json"
  SUBMISSION_ID="$(plutil -extract id raw -o - "$DMG.submission.json")"
fi
printf 'Submission: %s\n' "$SUBMISSION_ID"
xcrun notarytool wait "$SUBMISSION_ID" --keychain-profile "$PROFILE" --output-format json > "$DMG.notarization.json"
plutil -extract status raw -o - "$DMG.notarization.json" | grep -qx Accepted || {
  printf 'Notarization was not accepted; inspect %s.notarization.json and fetch its submission log.\n' "$DMG" >&2
  xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$PROFILE" "$DMG.notarization-log.json" || true
  exit 1
}
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
codesign --verify --strict "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
(cd "$(dirname "$DMG")" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
printf 'Notarized and validated: %s\n' "$DMG"
