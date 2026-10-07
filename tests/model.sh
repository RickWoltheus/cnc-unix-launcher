#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
APP="$SANDBOX/ModelChecks.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/manifests"
mkdir -p "$APP/Contents/Resources/resources"
cp "$REPO"/resources/*.json "$APP/Contents/Resources/resources/"
cp "$REPO"/manifests/*.tsv "$APP/Contents/Resources/manifests/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.generalsx-mac-launcher.tests</string>
<key>CFBundleExecutable</key><string>ModelChecks</string>
</dict></plist>
PLIST
xcrun swiftc -parse-as-library "$REPO/Sources/LauncherModel.swift" \
  "$REPO/Sources/RecoveryAdvice.swift" "$REPO/Sources/SteamGuidance.swift" "$REPO/tests/ModelChecks.swift" \
  "$REPO/Sources/SetupPolicy.swift" "$REPO/Sources/GameInfo.swift" "$REPO/Sources/Theme.swift" \
  -o "$APP/Contents/MacOS/ModelChecks"
"$APP/Contents/MacOS/ModelChecks"
