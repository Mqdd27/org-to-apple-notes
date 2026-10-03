#!/usr/bin/env osascript -l JavaScript
ObjC.import('Foundation');

function readFile(path) {
    const fm = $.NSFileManager.defaultManager;
    if (!fm.fileExistsAtPath(path)) return null;
    const data = fm.contentsAtPath(path);
    if (!data) return null;
    const nsStr = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding);
    return ObjC.unwrap(nsStr);
}

function writeFile(path, content) {
    const nsStr = $.NSString.alloc.initWithUTF8String(content);
    nsStr.writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
}

// Notes' scripting API can't write checklists (`body` drops them), but Notes'
// own "Create Note" Shortcuts action with "Interpret as Markdown" can, in the
// background. Install "Org to Apple Notes.shortcut" from this repo once.
const SHORTCUT = 'Org to Apple Notes';

const quote = (s) => `'${s.replace(/'/g, `'\\''`)}'`;

function run(argv) {
    if (argv.length < 3) {
        console.log("Usage: apple_notes_sync.js <title> <markdown-file-path> <id-cache-file-path>");
        return;
    }

    const title = argv[0];
    const mdPath = argv[1];
    const idCachePath = argv[2];

    const app = Application('Notes');
    const account = app.accounts.byName('iCloud');

    // Change this to the desired folder name if needed. For example, 'Notes' or 'Personal'.
    const folder = account.folders.byName('Personal');

    const cachedId = readFile(idCachePath);
    const old = cachedId ? account.notes.whose({ id: cachedId.trim() })()[0] : null;
    if (old && old.passwordProtected()) {
        console.log(`Note is locked, skipping sync: ${title}`);
        return;
    }

    // Shortcuts can only create notes, not replace a body, so every sync
    // creates a fresh note and deletes the previous one.
    const before = new Set(account.notes.id());
    const sh = Application.currentApplication();
    sh.includeStandardAdditions = true;
    // --output-path matters: without it `shortcuts` opens the created note,
    // which brings Notes to the front.
    sh.doShellScript(`/usr/bin/shortcuts run ${quote(SHORTCUT)} --input-path ${quote(mdPath)} --output-path /dev/null`);

    let note = null;
    for (let i = 0; i < 50 && !note; i++) {
        const id = account.notes.id().find((id) => !before.has(id));
        if (id) note = account.notes.byId(id);
        else delay(0.2);
    }
    if (!note) throw new Error(`Shortcut "${SHORTCUT}" ran but no new note appeared`);

    app.move(note, { to: folder });
    writeFile(idCachePath, note.id());

    if (old) {
        // Delete twice so Recently Deleted doesn't fill up with one copy per save.
        const oldId = old.id();
        app.delete(old);
        const trashed = account.folders.byName('Recently Deleted').notes.whose({ id: oldId })();
        if (trashed.length > 0) app.delete(trashed[0]);
    }
    console.log(`Synced note: ${title}`);
}
