# TaskMatrix

A lightweight macOS task prioritization app based on the **Eisenhower Matrix**. It helps you decide what to do *next*, not just list tasks.

Tasks live in a single window, organized into four quadrants by importance and urgency:

| | Urgent | Not Urgent |
|---|---|---|
| **Important** | Q1 · Do First | Q2 · Schedule |
| **Not Important** | Q3 · Delegate | Q4 · Eliminate |

## Features

- **Quick create** — add a task via the `+ New Task` button, `⌘N`, or the `+` button on any quadrant card (which preselects that quadrant); in the form, Tab moves from the title to the quadrant picker and cycles it, Enter submits, Esc cancels
- **2×2 matrix view** — all four quadrants visible at once, each with its own scrollable task list and task count
- **Edit in place** — double-click a task to rename it
- **Move & reorder by dragging** — drag a task onto another quadrant to move it, or drag it up/down within its own quadrant to reorder; the drop position (above or below a row) decides where it lands. Custom order persists. Right-click → *Move to* also works
- **Complete & delete** — checkbox to mark done (completed tasks fade and sink to the bottom); delete via right-click → *Delete*, or select a task and press ⌫ (a confirmation shows — Enter confirms)
- **Subtasks** — right-click a task → *Add Subtask…* to break it into steps; check steps off individually (the parent shows `done/total` progress), collapse/expand the list with the chevron, and rename or delete via right-click. Completing the parent completes all its subtasks
- **Due dates** — optionally set a date-only deadline (off by default): click *Add Due Date…* in the task form or right-click a task → *Set Due Date…*; both open a styled calendar popover where one click picks the day. The task shows a due badge ("Today", "Tomorrow", or the date) that turns red when overdue and amber when due today; clear it via the ✕ in the form or right-click → *Clear Due Date*
- **Statistics** — the *Statistics* button in the header opens a separate live-updating window: open/completed/overdue counts and on-time rate, open tasks per quadrant with a health insight, and a 14-day completion trend
- **Auto-save** — every change is persisted immediately; no manual save

## Persistence

Tasks are stored locally as JSON. The app is sandboxed, so the file lives in
its container:

```
~/Library/Containers/<bundle-id>/Data/Library/Application Support/TaskMatrix/tasks.json
```

Writes are atomic. Saves from older versions load unchanged — newer
optional fields (subtasks, due date) default gracefully.

### iCloud sync

Every change is also pushed to iCloud's key-value store, and payloads from
other devices are adopted automatically (last writer wins, newest
timestamp). The sync layer degrades gracefully: without the iCloud
entitlement it silently stays device-local.

To activate real cross-device sync, iCloud requires development signing:

1. Open the project in Xcode and sign in to an Apple Developer account
   (Settings → Accounts).
2. In *Signing & Capabilities*, pick your Team.
3. Set *Code Signing Entitlements* to `TaskMatrix/TaskMatrix.entitlements`
   (already in the repo, containing the key-value store entitlement), or
   add the iCloud → Key-value storage capability.

## Requirements & Building

- macOS with Xcode installed
- Swift 5 / AppKit (no external dependencies)

```sh
open TaskMatrix.xcodeproj
```

Then build and run the `TaskMatrix` scheme (⌘R).

## Project Structure

```
TaskMatrix/
├── TaskMatrix/
│   ├── AppDelegate.swift              # App lifecycle, light appearance
│   ├── ViewController.swift           # Main controller: layout, selection, sheets
│   ├── Models/
│   │   ├── Quadrant.swift             # Quadrant enum (titles, strategy)
│   │   └── TaskItem.swift             # TaskItem + SubTask models (Codable)
│   ├── Storage/
│   │   └── TaskStore.swift            # JSON load/save, task + subtask CRUD
│   ├── UI/
│   │   ├── Theme.swift                # Colors, quadrant accents, pasteboard type
│   │   ├── PillButton.swift           # Pill CTA with hover/press scale
│   │   ├── MatrixRootView.swift       # Key handling, background clicks
│   │   ├── QuadrantCardView.swift     # Quadrant card, task list, drop target
│   │   ├── TaskRowView.swift          # Task card with expandable subtasks
│   │   ├── SubtaskRowView.swift       # Indented subtask line
│   │   ├── QuadrantPicker.swift       # 2x2 quadrant tiles for the form
│   │   └── TaskFormViewController.swift  # Create/edit sheet (tasks + subtasks)
│   └── Base.lproj/Main.storyboard
├── task_matrix_requirements.md        # Product requirements
├── IMPLEMENTATION_PLAN.md             # Milestone plan
└── DESIGN.md                          # Visual design reference (Wise-inspired)
```

## Design

The UI takes cues from Wise's design language (see [DESIGN.md](DESIGN.md)): a warm off-white canvas, lime-green accent with dark-green text, heavy black display type, pill-shaped buttons with scale-on-hover animation, and large rounded cards with subtle ring borders.

## Scope

Explicitly out of scope for the MVP: sync, reminders, tags, AI, analytics.

## License

Public domain — see [LICENSE](LICENSE) (Unlicense).
