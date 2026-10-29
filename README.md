# Raf

A small macOS menu bar app for moving files and links around, in the spirit of Dropzone.

## How it works

- **Click the Raf menu bar icon** to open the shelf right under it. Click anywhere else to close it.
- **Drag files onto the menu bar icon** and the shelf opens. Keep dragging onto a target, or let go on the icon to put them on the Drop Bar.
- **Right-click the icon** for Show Shelf, Settings and Quit.
- The icon shows how many items are waiting on the Drop Bar.

The shelf has:

- **Drop Bar:** holds files and links until you drag them out again, to Finder or any app. Dragging out to the same disk moves the file, to another disk copies it, just like dragging from a Finder window. Double-click an item to open it, right-click for Show in Finder and Remove. Use the stack icon in the header to drag everything out at once.
- **Folders:** your own folder targets. Each one copies or moves what you drop into it, and never overwrites (a clash becomes `name 2.ext`). Drop a folder on **Add Folder** to add it as a target.
- **AirDrop:** opens the system AirDrop picker for what you dropped.
- **Shorten URL:** shortens a dropped link and copies the short link to the clipboard.

Clicking a target applies it to everything on the Drop Bar. Clicking **Shorten URL** shortens the link on the clipboard.

After a drag that opened it, the shelf closes by itself. Use the pin button to keep it open.

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later (or the Swift 5.9+ command-line tools)

## Build and run

```bash
scripts/build-app.sh
```

```bash
open build/Raf.app
```

To work on it in Xcode, open `Package.swift`. Running from Xcode or `swift run` works, but notifications and "Open at login" only work from the built `Raf.app`.

## Settings

Open them from the gear button on the shelf, or right-click the menu bar icon:

- **General:** also open the shelf whenever any file drag starts, open at login.
- **Folders:** add folder targets, rename them, choose copy or move, reorder them.
- **Short URL:** pick a service.
  - TinyURL: works without an account.
  - Bitly, Dub.co: need an API key.
  - Shlink, YOURLS (self-hosted): need your server address and an API key or signature token.

API keys are stored in the macOS Keychain, not in preferences.

## Notes

- Raf isn't sandboxed, so folder targets work with any path and the global drag detection works. That means it can't go on the Mac App Store as is; distribute it signed with a Developer ID and notarized instead.
- `build-app.sh` signs ad hoc. Each rebuild changes the signature, so macOS may ask again for Keychain access to saved API keys.
- Items that apps only offer as "file promises" (some Mail attachments, Photos) aren't supported yet.

## Code layout

```
Sources/Raf/
  App/        app entry, menu bar icon, global drag detection
  Shelf/      floating panel, drop handling, drag-out, shelf state, UI
  Actions/    folder copy/move, AirDrop, URL shorteners
  Settings/   preferences and the Settings window
  Support/    Keychain and notification helpers
```
