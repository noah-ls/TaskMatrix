#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/package_dmg.sh /path/to/TaskMatrix.app /path/to/TaskMatrix-version.dmg

Creates a drag-install DMG containing TaskMatrix.app and an Applications symlink.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

APP_PATH="${1:-}"
DMG_PATH="${2:-}"
VOLUME_NAME="${VOLUME_NAME:-TaskMatrix}"

if [[ -z "$APP_PATH" || -z "$DMG_PATH" ]]; then
  usage
  exit 2
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

if [[ "$DMG_PATH" != *.dmg ]]; then
  echo "DMG output path must end in .dmg: $DMG_PATH" >&2
  exit 1
fi

STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/taskmatrix-dmg.XXXXXX")"

cleanup() {
  rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

ditto "$APP_PATH" "$STAGE_DIR/TaskMatrix.app"
ln -s /Applications "$STAGE_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

