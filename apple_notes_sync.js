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

function run(argv) {
  if (argv.length < 3) {
    console.log("Usage: apple_notes_sync.js <title> <html-file-path> <id-cache-file-path>");
    return;
  }

  const title = argv[0];
  const htmlPath = argv[1];
  const idCachePath = argv[2];

  const html = readFile(htmlPath);
  const app = Application('Notes');
  app.includeStandardAdditions = true;

  const account = app.accounts.byName('iCloud');
  const folder = account.folders.byName('Personal');

  const cachedId = readFile(idCachePath);
  let target = null;

  if (cachedId) {
    const found = account.notes.whose({ id: cachedId.trim() });
    if (found.length > 0) {
      target = found[0];
    }
  }

  if (target) {
    target.body = html;
    console.log(`Updated existing note (matched by id): ${title}`);
  } else {
    const newNote = app.Note({ name: title, body: html });
    folder.notes.push(newNote);
    const newId = newNote.id();
    writeFile(idCachePath, newId);
    console.log(`Created new note and cached its id for future syncs: ${title}`);
  }
}
