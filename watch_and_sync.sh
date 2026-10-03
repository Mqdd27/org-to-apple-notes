#!/bin/bash
set -euo pipefail

ORG_FILE="${1:?Usage: $0 <path-to-org-file> [note-title]}"
NOTE_TITLE="${2:-Org Notes}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BASE_NAME="$(basename "$ORG_FILE" .org)"
SYNC_MD="/tmp/${BASE_NAME}_sync.md"

CACHE_DIR="$SCRIPT_DIR/.note_ids"
mkdir -p "$CACHE_DIR"
SLUG="$(echo "$NOTE_TITLE" | tr '[:upper:] ' '[:lower:]_')"
ID_CACHE="$CACHE_DIR/${SLUG}.id"

sync_once() {
  # Apple Notes uses the first line as the note title, so lead with #+title:
  local title
  title="$(grep -i -m1 '^#+title:' "$ORG_FILE" | cut -d: -f2- | sed 's/^[[:space:]]*//' || true)"
  {
    if [ -n "$title" ]; then printf '# %s\n\n' "$title"; fi
    # Notes shows every Markdown blank line as an empty line, but pandoc drops
    # the org file's blank lines and adds its own. So tag the line after each
    # run of org blank lines with QQBLANK<n>QQ (skipping #+begin/#+end blocks)...
    awk '/^[ \t]*#\+[Bb][Ee][Gg][Ii][Nn]_/ { inblock = 1 }
         /^[ \t]*$/ && !inblock { n++; print; next }
         {
           if (n && seen && !inblock && $0 !~ /^[ \t]*(#|\||:)/) {
             # after the headline stars / list bullet+checkbox / indentation
             match($0, /^(\*+ |[ \t]*([-+]|[0-9]+[.)]|[ \t]\*)( \[[ xX-]\])? |[ \t]*)/)
             $0 = substr($0, 1, RLENGTH) "QQBLANK" n "QQ " substr($0, RLENGTH + 1)
           }
           if ($0 ~ /^[ \t]*#\+[Ee][Nn][Dd]_/) inblock = 0
           n = 0; seen = 1; print
         }' "$ORG_FILE" |
      # ^:{} keeps snake_case literal; only x_{y} / x^{y} become sub/superscript.
      # Org * headlines become ## (Heading) since # is the note title.
      { echo '#+OPTIONS: ^:{}'; cat; } |
      pandoc -f org -t gfm --shift-heading-level-by=1 --wrap=none
  } |
    # ...then drop pandoc's blank lines and turn each tag back into n blank
    # lines. Exception: a paragraph right after a list needs one blank line,
    # or Notes folds it into the list.
    awk '/^```/ { fence = !fence }
         fence || /^```/ { print; next }
         /^$/ { blank = 1; next }
         {
           item = $0 ~ /^[ \t]*([-*+]|[0-9]+[.)]) /
           if (match($0, /QQBLANK[0-9]+QQ /)) {
             for (i = substr($0, RSTART + 7, RLENGTH - 10) + 0; i > 0; i--) print ""
             $0 = substr($0, 1, RSTART - 1) substr($0, RSTART + RLENGTH)
           } else if (blank && inlist && !item && $0 !~ /^#/) print ""
           inlist = item || (inlist && $0 ~ /^[ \t]/)
           blank = 0; print
         }' \
    > "$SYNC_MD"
  # One sync at a time across all watchers: apple_notes_sync.js finds the note
  # it created as "the note that wasn't there before", so concurrent syncs
  # would grab each other's notes.
  lockf /tmp/org-to-apple-notes.lock \
    osascript -l JavaScript "$SCRIPT_DIR/apple_notes_sync.js" "$NOTE_TITLE" "$SYNC_MD" "$ID_CACHE"
}

echo "Doing initial sync..."
sync_once

echo "Watching $ORG_FILE for changes (Ctrl+C to stop)..."
fswatch -o "$ORG_FILE" | while read -r _; do
  sync_once
  echo "$(date '+%H:%M:%S') synced -> Apple Notes: $NOTE_TITLE"
done
