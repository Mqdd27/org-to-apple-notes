# org-to-apple-notes
Sync org files to Apple Notes (one way: org → Notes), with org checkboxes
(`- [ ]` / `- [X]`) as native Apple Notes checklists. Syncing runs in the
background: no prompts, and Notes never takes focus.

## Installation

Requires macOS 26+ and an iCloud Notes account (Notes only imports Markdown
into iCloud notes).

1. Install the dependencies:
   ``` shell
   brew install pandoc fswatch
   ```
2. Install the shortcut: open `Org to Apple Notes.shortcut` from this repo and
   click **Add Shortcut**. Keep the name `Org to Apple Notes`, since
   `apple_notes_sync.js` runs it by that name.
3. Allow it to use Notes: run one sync by hand (see Usage) and choose
   **Always Allow** when macOS asks. Until you do, background syncs wait on
   that hidden prompt.
4. Pick the target folder: notes go to the iCloud folder `Personal`. To use a
   different folder (it must already exist), change this line in
   `apple_notes_sync.js`:
   ``` js
   const folder = account.folders.byName('Personal');
   ```

## Usage

``` shell
./watch_and_sync.sh <path-to-org-file> [note-key]
```

The script syncs once, then again on every save until you stop it with
Ctrl+C. `note-key` (default `Org Notes`) names the id cache in `.note_ids/`
that ties the org file to its note. Use a different key for each org file.

## Doom Emacs integration

Auto-sync any `.org` file to Apple Notes whenever it's opened in Doom Emacs.
Add this to `~/.config/doom/config.el`:

```elisp
(defun mqdd/org-watch-apple-notes ()
  "Start watch_and_sync.sh for this org file, once, if not already running."
  (interactive)
  (when buffer-file-name
    (let* ((proc-name (concat "org-to-apple-notes:" buffer-file-name))
           (proc (get-process proc-name))
           (process-environment
            (cons "PATH=/opt/homebrew/bin:/usr/bin:/bin"
                  process-environment)))
      (if (process-live-p proc)
          (message "org-to-apple-notes: already watching %s" buffer-file-name)
        (start-process proc-name "*org-to-apple-notes*"
                        (expand-file-name
                         "watch_and_sync.sh"
                         "~/Documents/projects/org-to-apple-notes")
                        buffer-file-name
                        (file-name-base buffer-file-name))
        (message "org-to-apple-notes: started watching %s" buffer-file-name)))))

(add-hook 'org-mode-hook #'mqdd/org-watch-apple-notes)
```

- Adjust the `PATH` and the repo path (`~/Documents/projects/org-to-apple-notes`)
  to match your machine. GUI apps like Emacs.app don't inherit your shell's
  `PATH`, so `pandoc` and `fswatch` must be found through this explicit
  `PATH`.
- After editing `config.el`, restart Emacs (or `M-x load-file` on it) so the
  hook is registered.
- This calls `watch_and_sync.sh` as-is: it starts once per opened `.org`
  buffer, and `fswatch` inside the script handles every later save. Output
  goes to the `*org-to-apple-notes*` buffer.

## How it works

1. `watch_and_sync.sh` converts the org file to Markdown with `pandoc` and
   keeps the blank lines exactly as they are in the org file.
2. `apple_notes_sync.js` runs the `Org to Apple Notes` shortcut, which uses
   Notes' own Create Note action with "Interpret as Markdown" to create a new
   note with native checklists.
3. It then moves the note into the target folder and permanently deletes the
   previous copy.

Notes' AppleScript API can't create checklists (it drops them from HTML),
which is why the sync uses a shortcut.

## Notes

- **Title:** the note's title comes from the org file's `#+title:`. Without
  one, Notes uses the first line of content.
- **Every save replaces the note:** a fresh note is created and the old copy
  is permanently deleted. Pins, links to the note, and anything you ticked or
  edited in Notes are lost on the next save.
- **Locked notes** are skipped.
- **Spacing:** org headlines become Notes headings (`*` → Heading,
  `**` → Subheading). A paragraph that directly follows a list always gets
  one empty line before it; without it, Notes merges the paragraph into the
  list.
- **After updating this repo,** restart running watchers (restart Emacs, or
  kill the `org-to-apple-notes:*` processes and reopen the buffers). A running
  watcher keeps using the old script.
