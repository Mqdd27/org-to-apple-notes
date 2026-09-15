#!/bin/bash
set -euo pipefail

ORG_FILE="${1:?Usage: $0 <path-to-org-file> [note-title]}"
NOTE_TITLE="${2:-Org Notes}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BASE_NAME="$(basename "$ORG_FILE" .org)"
RAW_HTML="/tmp/${BASE_NAME}_raw.html"
FIXED_HTML="/tmp/${BASE_NAME}_sync.html"

CACHE_DIR="$SCRIPT_DIR/.note_ids"
mkdir -p "$CACHE_DIR"
SLUG="$(echo "$NOTE_TITLE" | tr '[:upper:] ' '[:lower:]_')"
ID_CACHE="$CACHE_DIR/${SLUG}.id"

sync_once() {
  pandoc -f org -t html "$ORG_FILE" -o "$RAW_HTML"
  python3 "$SCRIPT_DIR/fix_notes.py" "$RAW_HTML" "$FIXED_HTML"
  osascript -l JavaScript "$SCRIPT_DIR/apple_notes_sync.js" "$NOTE_TITLE" "$FIXED_HTML" "$ID_CACHE"
}

echo "Doing initial sync..."
sync_once

echo "Watching $ORG_FILE for changes (Ctrl+C to stop)..."
fswatch -o "$ORG_FILE" | while read -r _; do
  sync_once
  echo "$(date '+%H:%M:%S') synced -> Apple Notes: $NOTE_TITLE"
done
