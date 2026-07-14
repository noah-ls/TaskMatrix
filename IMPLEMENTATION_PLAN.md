# Task Matrix macOS MVP Implementation Plan

Source requirements: [task_matrix_requirements.md](./task_matrix_requirements.md)

> **Status (July 2026):** Milestones 1–4 and most of 5 are implemented in
> `TaskMatrix/ViewController.swift`. Remaining: manual validation of the
> end-to-end flow and drag-and-drop stress test (plan section 6).

## 1. Goal and Scope

Build a single-window macOS app for Eisenhower Matrix task management with local auto-save.

Included in MVP:
- Create task (button and shortcut)
- Show tasks in 4 quadrants
- Move task across quadrants (drag and drop)
- Edit title
- Complete and delete task

Excluded in MVP:
- Sync, reminder, AI, tags, analytics

## 2. Technical Approach

Platform and architecture:
- macOS AppKit app (existing project structure)
- Keep one main window and one screen flow only
- Use simple layered design:
  - Model: `Task`, `Quadrant`
  - Storage: `TaskStore` (load/save)
  - UI: matrix view + task list views
  - Interaction: create/edit/move/complete/delete handlers

Persistence choice:
- Use local JSON file in app support directory for MVP
- Auto-save on every task mutation
- Load once at launch

## 3. Data Model and Rules

Data model:
- `Task { id, title, quadrant, isCompleted, createdAt }`

Validation and behavior rules:
- Title must be non-empty after trim
- Quadrant is required at create time
- `id` generated once and never changes
- `createdAt` set at creation only
- Complete action marks the task complete and fades it (task stays visible, sorted below active tasks, until deleted)

## 4. Milestone Plan

## Milestone 1: Base Structure and Models
Deliverables:
- Define `Quadrant` enum (Q1, Q2, Q3, Q4)
- Define `Task` model with Codable support
- Create `TaskStore` with in-memory state and CRUD API
- Wire app startup to load persisted tasks

Acceptance:
- App starts with empty state when no saved file exists
- App loads previously saved tasks without crash

## Milestone 2: Core Matrix UI (Single Window)
Deliverables:
- Build 2x2 matrix layout in main window
- Add clear labels for four quadrants
- Each quadrant shows a vertical list of task rows (title-only row baseline)
- Add top-bar `+` button and command shortcut `Cmd+N`

Acceptance:
- User can open add-task input from both entry points
- New task appears in selected quadrant immediately

## Milestone 3: Task Actions
Deliverables:
- Double-click to edit task title
- Right-click context menu with:
  - Move to Q1/Q2/Q3/Q4
  - Delete
- Checkbox for complete action

Acceptance:
- Edit updates UI and persistence
- Delete removes task and persists
- Complete behavior matches chosen UX (remove or fade) and persists

## Milestone 4: Drag and Drop
Deliverables:
- Enable drag source for task rows
- Enable drop targets for each quadrant
- On drop, update `quadrant`, refresh UI, auto-save
- Add safe handling for invalid drags

Acceptance:
- Drag and drop between any quadrants is stable
- No duplicate or lost task after repeated drags

## Milestone 5: Quality and Done Definition Validation
Deliverables:
- Keyboard flow polish (`Cmd+N`, Enter confirm, Esc cancel)
- Basic empty-state and error handling for storage failures
- Performance check for interaction loop (<1 second for typical actions)
- Manual test checklist for create -> move -> complete flow

Acceptance:
- Full create -> move -> complete flow in under 10 seconds
- No navigation beyond main screen
- Drag and drop behavior remains stable

## 5. File-Level Layout (Actual)

The code is split into layers (extracted once the single file grew past
~1,500 lines with the subtask feature):

- `Models/Quadrant.swift`, `Models/TaskItem.swift` — Codable models
- `Storage/TaskStore.swift` — JSON persistence and task/subtask CRUD
- `UI/` — theme, pill button, matrix root view, quadrant card, task and
  subtask rows, quadrant picker, and the task form sheet
- `ViewController.swift` — main controller: layout, selection, rendering,
  and sheet presentation

## 6. Test Plan (Manual MVP)

1. Create task from `+` button with each quadrant.
2. Create task from `Cmd+N`.
3. Edit title by double-click.
4. Move task by context menu to each quadrant.
5. Move task by drag and drop across all quadrant pairs.
6. Complete task and verify UI + persisted result.
7. Delete task and verify removal + persistence.
8. Relaunch app and verify data reload.
9. Stress test with 50+ tasks and fast drag operations.

## 7. Risks and Mitigations

- Drag and drop complexity in AppKit:
  - Mitigation: implement context-menu move first as fallback, then add DnD.
- Persistence corruption risk:
  - Mitigation: atomic file writes and JSON decode failure fallback.
- UI clutter risk:
  - Mitigation: keep row design minimal and avoid extra controls per row.

## 8. Definition of Done Checklist

- [x] Single window with 2x2 quadrant matrix
- [x] Add task via `+` and `Cmd+N`
- [x] Vertical task lists render correctly
- [x] Drag and drop between quadrants works reliably (implemented; stress test per section 6 still pending)
- [x] Double-click edit title works
- [x] Right-click move and delete works
- [x] Complete task behavior works and is consistent (fade + sort below active tasks)
- [x] Local auto-save and reload works
- [x] No multi-page navigation added
- [ ] End-to-end flow (create -> move -> complete) < 10 seconds (pending manual validation)
