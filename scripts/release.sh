#!/usr/bin/env bash
# Builds Kumquat, signs it with your Developer ID, has Apple notarize it, and checks the result
# the way Gatekeeper on another Mac will.
#
#   scripts/release.sh
#
# Once per Mac, beforehand:
#   1. Xcode → Settings → Accounts → your Apple ID → Manage Certificates → + → Developer ID Application.
#   2. An app-specific password from account.apple.com (Sign-In and Security → App-Specific Passwords), then:
#        xcrun notarytool store-credentials kumquat --apple-id YOU@EXAMPLE.COM --team-id TEAMID
#      It asks for that password and keeps it in your keychain; nothing is written to the repo.
# NOTARY_PROFILE picks another keychain profile, SIGN_IDENTITY another certificate.
set -euo pipefail
cd "$(dirname "$0")/.."

PROFILE="${NOTARY_PROFILE:-kumquat}"
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)}"
[ -n "$IDENTITY" ] || { echo "No Developer ID Application certificate in the keychain (see step 1 above)." >&2; exit 1; }
xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 \
  || { echo "No notarytool profile \"$PROFILE\" in the keychain (see step 2 above)." >&2; exit 1; }
[ -x .ffmpeg/bin/ffmpeg ] || { echo "== Building FFmpeg first (about 10 minutes, once)"; scripts/build-ffmpeg.sh; }

echo "== Building"
scripts/bundle.sh
APP="build/Kumquat.app"

echo "== Signing with $IDENTITY"
# Inside out: the bundled FFmpeg first, then the app around it. Hardened runtime and a secure timestamp
# are what notarization requires.
if [ -f "$APP/Contents/MacOS/ffmpeg" ]; then
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP/Contents/MacOS/ffmpeg"
fi
codesign --force --options runtime --timestamp --entitlements Resources/Kumquat.entitlements \
  --sign "$IDENTITY" "$APP"
codesign --verify --strict --deep --verbose=2 "$APP"

echo "== Notarizing (Apple usually answers within a few minutes)"
rm -f build/Kumquat.zip
ditto -c -k --keepParent "$APP" build/Kumquat-notarize.zip
xcrun notarytool submit build/Kumquat-notarize.zip --keychain-profile "$PROFILE" --wait | tee build/notarize.log
grep -q "status: Accepted" build/notarize.log || {
  id="$(sed -n 's/^ *id: //p' build/notarize.log | head -1)"
  echo "Apple didn't accept the build. Its log:" >&2
  [ -n "$id" ] && xcrun notarytool log "$id" --keychain-profile "$PROFILE" >&2
  exit 1
}
rm build/Kumquat-notarize.zip

echo "== Stapling and checking"
xcrun stapler staple "$APP"
spctl --assess --type execute -vv "$APP"
ditto -c -k --keepParent "$APP" build/Kumquat.zip
echo "Notarized: $APP and build/Kumquat.zip"
