#!/bin/bash
# watch & sync when there is any changes to the org files


set -euo pipefail

ORG_FILE="${1:?Usage: $0 <path-to-org-file> [note-title]}"
NOTE_TITLE="${2:-Org Notes}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_HTML="/tmp/$(basename "$ORG_FILE" .org)_sync.html"

sync_once() {
  pandoc -f org -t html "$ORG_FILE" -o "$TMP_HTML"
  osascript -l JavaScript "$SCRIPT_DIR/apple_notes_sync.js" "$NOTE_TITLE" "$TMP_HTML"
}

echo "Doing initial sync..."
sync_once

echo "Watching $ORG_FILE for changes (Ctrl+C to stop)..."
fswatch -o "$ORG_FILE" | while read -r _; do
  sync_once
  echo "$(date '+%H:%M:%S') synced -> Apple Notes: $NOTE_TITLE"
done
