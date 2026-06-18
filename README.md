# Hangar

A native macOS (Tahoe / macOS 26, Liquid Glass) app for managing the Firebase
apps created by the [`my-setup-scripts`](../my-setup-scripts) shell tools. It's a
SwiftUI front-end over those scripts — the shell version keeps working exactly as
before; this is a graphical way to drive the same operations.

## What it does

- **Sidebar** — your apps from `apps-registry.json`, split into **Active** and
  **Archived** tabs, each with an initials glyph and primary domain.
- **Detail** — for the selected app: local root folder (reveal in Finder / copy),
  custom domains *and* the raw Firebase `*.web.app` URL, a link to the Firebase
  Console overview, the GitHub repo, and a live **Action runs** history pulled
  from GitHub Actions via `gh run list`.
- **Add app** (the `+` button or ⌘N) — a dialog with two tabs:
  - **Create app** — the App ID, both default domains, and the Firebase Project
    ID **auto-populate from the app name as you type**. Edit any field and that
    field stops auto-filling (its "Auto" badge disappears) while the others keep
    tracking. Click **Create** and you land on the new app's detail page,
    watching `setup-new-app.sh` stream its output live; when it finishes
    successfully the page becomes a normal detail page.
  - **Manually log app** — every registry field (id, name, domains, local root,
    Firebase project id, GitHub repo, status, created-at) with the same
    name-driven auto-fill. **No provisioning** — it just appends the entry to
    `apps-registry.json` and commits/pushes it, the way the scripts do. Used for
    migrating legacy apps into the registry.
- **Archive / Restore** — runs `remove-app.sh` / `host-manager.sh restore-app`
  with a confirmation and a live output sheet.

## Architecture

Hangar is a thin native orchestrator, not a reimplementation:

- It **reads** `<scripts>/apps-registry/apps-registry.json` directly (the same
  file the scripts read/write/commit).
- It **shells out** to the existing scripts through a login `zsh` so they find
  `gh`, `gcloud`, `firebase`, `jq`, `npm`, etc., streaming combined stdout/stderr
  into a terminal-style console (`ScriptRunner`).
- Registry decoding is **schema-tolerant**: it prefers the new `domains` (array)
  and `local_root` fields but falls back to the legacy `domain` string and a path
  computed from `LOCAL_PROJECTS_DIR` in `.deploy-secrets`, so older entries just
  work.

### Source layout (`Hangar/`)

| Area | Files |
|---|---|
| Models | `ManagedApp`, `DeploySecrets`, `ActionRun`, `AppAction`, `CreateDraft` |
| Services | `AppController` (central state), `ScriptRunner`, `GitHubService`, `Paths`, `Shell` |
| Views | `RootView`, `SidebarView`, `AppDetailView`, `ActionRunsList`, `CreatingView`, `CreateAppSheet`, `ActionProgressSheet`, `ConsoleView`, `Components` |
| Theme | `Theme` (brand gradient + the `glassCard` Liquid Glass helper) |

## Companion script changes

`setup-new-app.sh` got three small **additive** changes (it still runs fine on
its own):

1. An optional `-fid, --firebase-id` flag (so the GUI's Firebase Project ID is
   honored; otherwise it's generated as before).
2. It now writes `domains` (array) and `local_root` into the registry alongside
   the legacy `domain` string.

## Build & run

Requires Xcode 26+ on macOS 26.

```sh
open Hangar/Hangar.xcodeproj      # then press Run (⌘R)
# or:
xcodebuild -project Hangar/Hangar.xcodeproj -scheme Hangar -configuration Debug build
```

The build product is `Hangar.app`. On first launch it looks for the scripts at
`~/Projects/server-setup-scripts/my-setup-scripts` (and a couple of fallbacks).
If it can't find them, the empty state offers **Locate Setup Scripts…** to pick
the folder containing `setup-new-app.sh`.

> Not sandboxed — it spawns the setup scripts and reads your projects directory,
> which the App Sandbox would block. Fine for a personal local tool; it would
> need rework to ship via the Mac App Store.

## Notes / future work

- App glyphs are gradient initials for now — drop in real per-app iconography
  when it's ready (`AppGlyph` in `Components.swift`).
- The registry is read on demand; use the refresh button (or ⌘R) to pick up
  changes made by running the shell scripts directly in a terminal.
