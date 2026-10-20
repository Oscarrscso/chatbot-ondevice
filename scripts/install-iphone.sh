#!/usr/bin/env bash
set -euo pipefail
# Build, install, and launch PocketChat on your iPhone.
# Usage: bash scripts/install-iphone.sh [DEVICE_ID]
# Optional: APPLE_TEAM_ID=TEAMID bash scripts/install-iphone.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
die() { echo "Error: $*" >&2; exit 1; }

if [[ $# -gt 0 && "$1" == "--help" ]]; then
  echo "Usage: bash scripts/install-iphone.sh [IPHONE_DEVICE_ID]"
  exit 0
fi
[[ $# -le 1 ]] || die "Pass at most one iPhone device ID."
command -v xcodebuild >/dev/null || die "Install full Xcode and select it under Xcode > Settings > Locations > Command Line Tools."
xcrun --find devicectl >/dev/null 2>&1 || die "devicectl unavailable. Select full Xcode in Settings > Locations."
[[ -f PocketChat.xcodeproj/project.pbxproj ]] || die "PocketChat.xcodeproj is missing."

DEVICE_ID="$(printenv IOS_DEVICE_ID || true)"
if [[ $# -eq 1 ]]; then DEVICE_ID="$1"; fi

if [[ -z "$DEVICE_ID" ]]; then
  command -v python3 >/dev/null || {
    xcrun devicectl list devices
    die "Python 3 unavailable for automatic detection. Pass your device ID as the first argument."
  }
  DEVICE_JSON="$(mktemp)"
  trap 'rm -f "$DEVICE_JSON"' EXIT
  xcrun devicectl list devices --json-output "$DEVICE_JSON" >/dev/null || die "Cannot list iPhones. Connect, unlock and trust your iPhone."
  DEVICE_ID="$(python3 - "$DEVICE_JSON" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as f:
    devices = json.load(f).get("result", {}).get("devices", [])
found = {}
for d in devices:
    props = d.get("deviceProperties") or {}
    hw = d.get("hardwareProperties") or {}
    conn = d.get("connectionProperties") or {}
    device_name = str(props.get("name") or "")
    device_type = str(hw.get("deviceType") or hw.get("productType") or "")
    if "iphone" not in (device_name + device_type).lower():
        continue
    if str(conn.get("pairingState") or "").lower() not in ("", "paired"):
        continue
    if str(conn.get("transportType") or "").lower() in ("none", "unavailable"):
        continue
    key = d.get("identifier") or hw.get("udid")
    if key:
        found[str(key)] = device_name
if not found:
    sys.exit("No connected iPhone found. Connect USB, unlock, trust this Mac and enable Developer Mode.")
if len(found) > 1:
    for key, name in found.items():
        print(f"{name}: {key}", file=sys.stderr)
    sys.exit("Multiple iPhones detected. Rerun with your desired device ID.")
print(next(iter(found)))
PY
)" || die "Could not auto-select iPhone. Run: xcrun devicectl list devices"
fi

DERIVED="$ROOT/.build/DerivedData"
APP="$DERIVED/Build/Products/Debug-iphoneos/PocketChat.app"
TEAM="$(printenv APPLE_TEAM_ID || true)"
if [[ -n "$TEAM" ]]; then
  set -- "DEVELOPMENT_TEAM=$TEAM"
else
  set --
fi
echo "Building PocketChat for iPhone: $DEVICE_ID"
xcodebuild -project PocketChat.xcodeproj -scheme PocketChat -configuration Debug \
  -destination "platform=iOS,id=$DEVICE_ID" -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build "$@" \
  || die "Build failed. Open PocketChat.xcodeproj and configure Signing & Capabilities > Team."
[[ -d "$APP" ]] || die "Build completed but app was not found at $APP."
echo "Installing PocketChat..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP" \
  || die "Installation failed. Make sure the iPhone is unlocked, trusted and in Developer Mode."
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
echo "Installed $BUNDLE_ID. Attempting launch..."
if ! xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"; then
  echo "Installation succeeded; open PocketChat manually from your iPhone Home Screen."
fi
