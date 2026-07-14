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
- **Move between quadrants** — drag a task onto another quadrant, or right-click → *Move to*
- **Complete & delete** — checkbox to mark done (completed tasks fade and sink to the bottom); delete via right-click → *Delete*, or select a task and press ⌫ (a confirmation shows — Enter confirms)
- **Subtasks** — right-click a task → *Add Subtask…* to break it into steps; check steps off individually (the parent shows `done/total` progress), collapse/expand the list with the chevron, and rename or delete via right-click. Completing the parent completes all its subtasks
- **Due dates** — optionally set a date-only deadline (off by default): pick a day on the form's click-through calendar, or right-click a task → *Due Date* for quick picks (Today / Tomorrow / Next Week / Custom… / Clear). The task shows a due badge ("Today", "Tomorrow", or the date) that turns red when overdue and amber when due today
- **Auto-save** — every change is persisted immediately; no manual save

## Persistence

Tasks are stored locally as JSON. The app is sandboxed, so the file lives in
its container:

```
~/Library/Containers/<bundle-id>/Data/Library/Application Support/TaskMatrix/tasks.json
```

Writes are atomic; there is no sync, no account, no network access. Saves
from older versions load unchanged — newer optional fields (subtasks, due
date) default gracefully.

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
