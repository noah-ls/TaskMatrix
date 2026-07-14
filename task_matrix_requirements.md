# 📌 Task Matrix (macOS) – Requirement Document

## 1. Overview

**Task Matrix** is a macOS desktop app that helps users manage tasks using the Eisenhower Matrix.

Core idea:  
Users organize tasks into 4 quadrants based on **importance** and **urgency**.

---

## 2. Core UI (Single Window)

### Layout
- One main window
- 2x2 grid (4 quadrants)

```
| Q1 | Q2 |
|----|----|
| Q3 | Q4 |
```

### Quadrants
- Q1: Important + Urgent  
- Q2: Important + Not Urgent  
- Q3: Not Important + Urgent  
- Q4: Not Important + Not Urgent  

---

## 3. Core Features

### 3.1 Add Task
- Entry points:
  - “+” button (top bar)
  - Shortcut (⌘ + N)

- Input:
  - Title (required)
  - Quadrant (required)

---

### 3.2 Task Display
- Each quadrant shows a vertical list of tasks
- Task = simple row (title only)

---

### 3.3 Move Task
- Drag & drop between quadrants

---

### 3.4 Edit Task
- Double click → edit title
- Right click menu:
  - Move to another quadrant
  - Delete

---

### 3.5 Complete Task
- Checkbox on task
- On complete:
  - Task fades and sorts below active tasks (stays until deleted)

---

## 4. Interaction Rules

- Drag = primary interaction  
- No complex navigation (no multi-page flow)  
- All actions within main window  

---

## 5. Data Model

```
Task {
  id: String
  title: String
  quadrant: Q1 | Q2 | Q3 | Q4
  isCompleted: Bool
  createdAt: Date
  subtasks: [SubTask]
}

SubTask {
  id: String
  title: String
  isCompleted: Bool
}
```

---

## 6. Persistence

- Local storage only
- Auto-save (no manual save)

---

## 7. MVP Scope

### Included
- Create task  
- Display in matrix  
- Drag to move  
- Edit title  
- Complete / delete  

### Excluded
- Sync  
- Reminder  
- AI  
- Tags  
- Analytics  

---

## 8. UX Principles

- Zero learning cost  
- Keyboard-friendly  
- Fast (<1s interaction loop)  
- No visual clutter  

---

## 9. Done Definition

App is complete when:
- User can create → move → complete tasks in <10 seconds flow  
- No navigation beyond main screen  
- Stable drag & drop behavior  
