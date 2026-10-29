# Raf

A small macOS menu bar app for moving files and links around, in the spirit of Dropzone.

Start dragging a file or link anywhere and Raf slides a shelf in at the right edge of the screen. Drop onto:

- **The shelf.** Holds files and links until you drag them out again.
- **Folders.** Your own folder targets. Each one copies or moves what you drop into it, and never overwrites (a clash becomes `name 2.ext`).
- **AirDrop.** Opens the system AirDrop picker for what you dropped.
- **Shorten URL.** Shortens a dropped link and copies the short link to the clipboard.

Clicking a target applies it to everything on the shelf. Clicking **Shorten URL** shortens the link that's on the clipboard.

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

Open them from the menu bar icon (**Settings…**):

- **General:** show the shelf automatically while dragging, open at login.
- **Folders:** add folder targets, rename them, choose copy or move, reorder them.
- **Short URL:** pick a service.
  - TinyURL: works without an account.
  - Bitly, Dub.co: need an API key.
  - Shlink, YOURLS (self-hosted): need your server address and an API key or signature token.

API keys are stored in the macOS Keychain, not in preferences.

## Notes

- Raf isn't sandboxed, so folder targets work with any path and the global drag detection works. That means it can't go on the Mac App Store as is; distribute it signed with a Developer ID and notarized instead.
- `build-app.sh` signs ad hoc. Each rebuild changes the signature, so macOS may ask again for Keychain access to saved API keys.

## Code layout

```
Sources/Raf/
  App/        app entry, menu bar menu, global drag detection
  Shelf/      floating panel, shelf state, drop handling, UI
  Actions/    folder copy/move, AirDrop, URL shorteners
  Settings/   preferences and the Settings window
  Support/    Keychain and notification helpers
```
