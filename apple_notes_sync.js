#!/usr/bin/env osascript -l JavaScript
// Usage: osascript -l JavaScript apple-notes-sync.js "<Note Title>" "/path/to/file.html"
// Creates the note if it doesn't exist, otherwise overwrites its body.

ObjC.import('Foundation');

function readFile(path) {
  const fm = $.NSFileManager.defaultManager;
  const data = fm.contentsAtPath(path);
  if (!data) {
    throw new Error(`Could not read file at ${path}`);
  }
  const nsStr = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding);
  return ObjC.unwrap(nsStr);
}

function run(argv) {
  if (argv.length < 2) {
    console.log("Usage: apple-notes-sync.js <title> <html-file-path>");
    return;
  }

  const title = argv[0];
  const htmlPath = argv[1];

  // Read the file ourselves (NOT via Notes.app's sandbox) to avoid -10004
  const html = readFile(htmlPath);

  const app = Application('Notes');
  app.includeStandardAdditions = true;

  // Account is 'iCloud' — 'Personal' is a FOLDER inside it, not an account
  const account = app.accounts.byName('iCloud');
  const folder = account.folders.byName('Personal');
  const existing = folder.notes.whose({ name: title });

  if (existing.length > 0) {
    existing[0].body = html;
    console.log(`Updated existing note: ${title}`);
  } else {
    const newNote = app.Note({ name: title, body: html });
    folder.notes.push(newNote);
    console.log(`Created new note: ${title}`);
  }
}
