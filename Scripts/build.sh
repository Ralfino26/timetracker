#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build"
APP_DIR="$BUILD_DIR/TimeTracker.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

cd "$ROOT"
swift build -c release

BIN="$BUILD_DIR/release/Timetracker"
RESOURCE_BUNDLE="$BUILD_DIR/release/Timetracker_Timetracker.bundle"

if [[ ! -x "$BIN" ]]; then
  echo "error: release binary missing at $BIN" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BIN" "$MACOS/TimeTracker"
chmod +x "$MACOS/TimeTracker"
cp "$ROOT/Timetracker/Info.plist" "$CONTENTS/Info.plist"

if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES/"
fi

echo "Built $APP_DIR"
