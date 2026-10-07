#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
APP="$SANDBOX/SteamGuideChecks.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/resources" "$APP/Contents/Resources/manifests"
cp "$REPO"/resources/*.json "$APP/Contents/Resources/resources/"
cp "$REPO"/manifests/*.tsv "$APP/Contents/Resources/manifests/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.generalsx-mac-launcher.guidechecks</string>
<key>CFBundleExecutable</key><string>SteamGuideChecks</string>
</dict></plist>
PLIST
xcrun swiftc -parse-as-library "$REPO/Sources/LauncherModel.swift" "$REPO/Sources/ProductInfo.swift" \
  "$REPO/Sources/RecoveryAdvice.swift" "$REPO/Sources/SteamGuidance.swift" \
  "$REPO/Sources/SetupPolicy.swift" "$REPO/Sources/GameInfo.swift" "$REPO/Sources/Theme.swift" \
  "$REPO/Sources/SteamGuide.swift" "$REPO/tests/SteamGuideChecks.swift" \
  -o "$APP/Contents/MacOS/SteamGuideChecks"
"$APP/Contents/MacOS/SteamGuideChecks"
