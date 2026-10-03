# org-to-apple-notes
Sync org files to apple notes

Requires macOS 26+, an iCloud Notes account, `pandoc` and `fswatch`:
``` shell
brew install pandoc fswatch
```

Then install the shortcut once: open `Org to Apple Notes.shortcut`, click
**Add Shortcut**, and choose **Always Allow** when the first sync asks for
Notes access. Notes' scripting API can't create checklists; this shortcut uses
Notes' own Markdown importer so org checkboxes (`- [ ]` / `- [X]`) become
native checklists, in the background.

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
            (cons "PATH=/Users/macbook/.pyenv/shims:/opt/homebrew/bin:/usr/bin:/bin"
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

Notes:
- This only works one way only (Emacs -> Apple Notes)
- Every save replaces the note with a fresh one (the old copy is deleted
  permanently), so pins, note links and edits made in Notes don't survive a
  sync.
- On `apple_notes_sync.js` change the ```const folder = account.folder.byName``` to desired folder name
- This calls `watch_and_sync.sh` as-is (no logic duplicated in elisp) — it starts
  once per opened `.org` buffer and `fswatch` inside the script handles every
  subsequent save.
- Adjust the `PATH` and the repo path (`~/Documents/projects/org-to-apple-notes`)
  to match your machine. GUI apps like Emacs.app don't inherit your shell's
  `PATH`, so `pandoc`/`fswatch` must be resolvable through this explicit
  `PATH`.
- After editing `config.el`, restart Emacs (or `M-x load-file` on it) so the
  hook is registered.
- The note's title in the Notes list comes from the org file's `#+title:`
  (inserted as the first line of the body, which Apple Notes uses as the
  title). Without `#+title:` it falls back to the first line of content. The
  `NOTE_TITLE` argument is only used to key the id-cache so re-syncs
  replace the same note instead of creating duplicates.

