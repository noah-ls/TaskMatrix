# TaskMatrix

TaskMatrix is a lightweight macOS task prioritization app based on the
Eisenhower Matrix. It keeps planning simple: decide what to do now, schedule,
delegate, or eliminate.

Tasks are organized into four quadrants:

| | Urgent | Not Urgent |
|---|---|---|
| Important | Q1 - Do First | Q2 - Schedule |
| Not Important | Q3 - Delegate | Q4 - Eliminate |

## Features

- 2x2 matrix view with all four quadrants visible in one window.
- Quick task creation from the toolbar, keyboard shortcut, or quadrant cards.
- Edit tasks by double-clicking a row.
- Drag tasks between quadrants or reorder them inside a quadrant.
- Right-click task actions: pin/unpin, add subtask, set due date, move, archive,
  and delete.
- Subtasks with individual completion state and expandable rows.
- Date-only due dates with Today, Tomorrow, overdue, and absolute-date display.
- Pinned tasks stay at the top of their open/completed group.
- Completed tasks are visually muted and sorted below open tasks.
- Archived Tasks window with restore and delete actions.
- Automatic archive for completed tasks older than the configured threshold.
- Settings window from the macOS app menu for archive retention.
- Statistics window for open, completed, overdue, on-time, quadrant, and trend
  metrics.
- Local JSON persistence with atomic writes.
- Optional iCloud key-value sync when the app is signed with the required
  entitlement.

## Requirements

- macOS
- Xcode with Swift 5 and AppKit support
- No external package dependencies

## Bundle Identifiers

The open-source defaults are:

- App target: `io.github.noah-ls.TaskMatrix`
- Test target: `io.github.noah-ls.TaskMatrixTests`

If you ship your own build, change these identifiers to values you control.
If you enable iCloud key-value sync, the bundle identifier must also match the
Apple Developer App ID and entitlement configuration for your team.

## Building

Open the project in Xcode:

```sh
open TaskMatrix.xcodeproj
```

Then choose the `TaskMatrix` scheme and run it.

Command-line build:

```sh
xcodebuild build -project TaskMatrix.xcodeproj -scheme TaskMatrix -destination 'platform=macOS'
```

Release build:

```sh
xcodebuild build -project TaskMatrix.xcodeproj -scheme TaskMatrix -configuration Release -destination 'platform=macOS'
```

## Testing

Run the logic test suite:

```sh
xcodebuild test -project TaskMatrix.xcodeproj -scheme TaskMatrixTests -destination 'platform=macOS'
```

The test target covers models, backward-compatible decoding, date formatting,
statistics, persistence, task CRUD, subtasks, drag reorder, pinning, archiving,
and restore behavior.

## Continuous Integration

GitHub Actions runs the app build and unit tests on every push to `main` and on
pull requests. See `.github/workflows/ci.yml`.

## Persistence

Tasks are stored locally as JSON. Because the app is sandboxed, the file lives
inside the app container:

```text
~/Library/Containers/<bundle-id>/Data/Library/Application Support/TaskMatrix/tasks.json
```

Writes are atomic. New optional fields are decoded with defaults so older save
files continue to load.

## iCloud Sync

`TaskCloudSync` mirrors the task list to iCloud key-value storage and adopts
newer remote payloads using last-writer-wins semantics. The app works without
iCloud signing; sync simply remains local-only when the entitlement is absent.

To enable iCloud sync in your own distribution:

1. Sign in to an Apple Developer account in Xcode.
2. Select your development team in Signing & Capabilities.
3. Use a bundle identifier registered to your team.
4. Add the iCloud key-value storage entitlement or configure
   `TaskMatrix/TaskMatrix.entitlements` for your target.

## Packaging

Generated DMG files are ignored by git. For public releases, build the Release
configuration and attach the DMG to a GitHub Release. For end-user
distribution, sign and notarize the app with your own Apple Developer ID.

## Project Structure

```text
TaskMatrix/
├── TaskMatrix/
│   ├── AppDelegate.swift
│   ├── ViewController.swift
│   ├── Models/
│   │   ├── Quadrant.swift
│   │   └── TaskItem.swift
│   ├── Storage/
│   │   ├── AppSettings.swift
│   │   ├── TaskCloudSync.swift
│   │   └── TaskStore.swift
│   ├── Stats/
│   │   ├── StatsCalculator.swift
│   │   └── StatsViewController.swift
│   ├── UI/
│   │   ├── ArchiveViewController.swift
│   │   ├── CalendarPickerView.swift
│   │   ├── CalendarPopover.swift
│   │   ├── DueDateFormatting.swift
│   │   ├── MatrixRootView.swift
│   │   ├── PillButton.swift
│   │   ├── QuadrantCardView.swift
│   │   ├── QuadrantPicker.swift
│   │   ├── SettingsViewController.swift
│   │   ├── SubtaskRowView.swift
│   │   ├── TaskFormViewController.swift
│   │   ├── TaskRowView.swift
│   │   └── Theme.swift
│   └── Base.lproj/Main.storyboard
├── TaskMatrixTests/
├── .github/
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── SUPPORT.md
├── PRIVACY.md
└── LICENSE
```

## Contributing

Issues and pull requests are welcome. Read `CONTRIBUTING.md` before opening a
PR. For security issues, follow `SECURITY.md` instead of filing a public issue.

## Privacy

TaskMatrix stores task data locally and can optionally sync through the user's
own iCloud account. It does not include analytics, advertising, or third-party
network services. See `PRIVACY.md`.

## License

TaskMatrix is released under the MIT License. See `LICENSE`.
