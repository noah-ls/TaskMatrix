import Cocoa

final class ViewController: NSViewController {
    private let store = TaskStore()
    private var quadrantViews: [Quadrant: QuadrantCardView] = [:]
    private var didInstallCommandN = false
    private var selectedTaskID: String?
    private var collapsedTaskIDs: Set<String> = []

    override func loadView() {
        let rootView = MatrixRootView(frame: NSRect(x: 0, y: 0, width: 1080, height: 720))
        rootView.onDeleteKeyPressed = { [weak self] in
            self?.confirmAndDeleteSelectedTask()
        }
        rootView.onBackgroundClicked = { [weak self] in
            self?.clearSelection()
        }
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupRootUI()
        bindStore()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        installCommandNShortcutIfNeeded()

        view.window?.title = "Task Matrix"
        view.window?.minSize = NSSize(width: 760, height: 560)
        view.window?.makeFirstResponder(view)
    }

    // MARK: - Layout

    private func setupRootUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.taskCanvas.cgColor

        // Header — one compact line: title on the left, actions on the right.
        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.attributedStringValue = NSAttributedString(
            string: "Task Matrix",
            attributes: [
                .font: NSFont.systemFont(ofSize: 22, weight: .black),
                .foregroundColor: NSColor.taskInk,
                .kern: -0.4
            ]
        )

        let subtitleLabel = NSTextField(labelWithString: "Decide what to do next — not just list tasks.")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = NSColor.taskMuted

        let titleStack = NSStackView(views: [titleLabel, subtitleLabel])
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 1

        let shortcutHint = NSTextField(labelWithString: "⌘N")
        shortcutHint.translatesAutoresizingMaskIntoConstraints = false
        shortcutHint.font = .systemFont(ofSize: 12, weight: .semibold)
        shortcutHint.textColor = NSColor.taskMuted

        let addTaskButton = PillButton(title: "+ New Task", target: self, action: #selector(handleAddTaskAction(_:)))

        let headerSpacer = NSView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let headerRow = NSStackView(views: [titleStack, headerSpacer, shortcutHint, addTaskButton])
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 12

        // Matrix — a true 2x2 grid; rows pinned to full width so columns align.
        let topRow = NSStackView()
        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.orientation = .horizontal
        topRow.distribution = .fillEqually
        topRow.spacing = 14

        let bottomRow = NSStackView()
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        bottomRow.orientation = .horizontal
        bottomRow.distribution = .fillEqually
        bottomRow.spacing = 14

        for quadrant in [Quadrant.q1, .q2] {
            topRow.addArrangedSubview(makeQuadrantCard(for: quadrant))
        }

        for quadrant in [Quadrant.q3, .q4] {
            bottomRow.addArrangedSubview(makeQuadrantCard(for: quadrant))
        }

        let matrixStack = NSStackView(views: [topRow, bottomRow])
        matrixStack.translatesAutoresizingMaskIntoConstraints = false
        matrixStack.orientation = .vertical
        matrixStack.distribution = .fillEqually
        matrixStack.alignment = .leading
        matrixStack.spacing = 14

        view.addSubview(headerRow)
        view.addSubview(matrixStack)

        NSLayoutConstraint.activate([
            headerRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            headerRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            headerRow.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),

            matrixStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            matrixStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            matrixStack.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 16),
            matrixStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            topRow.widthAnchor.constraint(equalTo: matrixStack.widthAnchor),
            bottomRow.widthAnchor.constraint(equalTo: matrixStack.widthAnchor)
        ])
    }

    private func makeQuadrantCard(for quadrant: Quadrant) -> QuadrantCardView {
        let card = QuadrantCardView(quadrant: quadrant)
        card.onTaskDropped = { [weak self] taskID in
            self?.store.moveTask(id: taskID, to: quadrant)
        }
        card.onAddRequested = { [weak self] in
            self?.presentAddTaskDialog(preselected: quadrant)
        }
        quadrantViews[quadrant] = card
        return card
    }

    // MARK: - Rendering

    private func bindStore() {
        store.onChange = { [weak self] tasks in
            self?.render(tasks: tasks)
        }

        render(tasks: store.tasks)
    }

    private func render(tasks: [TaskItem]) {
        let actions = TaskListActions(
            toggleCompleted: { [weak self] taskID, isCompleted in
                self?.store.setTaskCompleted(id: taskID, isCompleted: isCompleted)
            },
            edit: { [weak self] taskID in
                self?.presentEditTaskDialog(taskID: taskID)
            },
            move: { [weak self] taskID, destination in
                self?.store.moveTask(id: taskID, to: destination)
            },
            delete: { [weak self] taskID in
                self?.store.deleteTask(id: taskID)
            },
            select: { [weak self] taskID in
                self?.selectTask(taskID)
            },
            setDueDate: { [weak self] taskID, dueDate in
                self?.store.updateDueDate(id: taskID, dueDate: dueDate)
            },
            addSubtask: { [weak self] taskID in
                self?.presentAddSubtaskDialog(taskID: taskID)
            },
            toggleSubtask: { [weak self] taskID, subtaskID, isCompleted in
                self?.store.setSubtaskCompleted(taskID: taskID, subtaskID: subtaskID, isCompleted: isCompleted)
            },
            editSubtask: { [weak self] taskID, subtaskID in
                self?.presentEditSubtaskDialog(taskID: taskID, subtaskID: subtaskID)
            },
            deleteSubtask: { [weak self] taskID, subtaskID in
                self?.store.deleteSubtask(taskID: taskID, subtaskID: subtaskID)
            },
            toggleExpanded: { [weak self] taskID in
                self?.toggleExpanded(taskID: taskID)
            }
        )

        for quadrant in Quadrant.allCases {
            let quadrantTasks = tasks.filter { $0.quadrant == quadrant }
            quadrantViews[quadrant]?.render(
                tasks: quadrantTasks,
                selectedTaskID: selectedTaskID,
                collapsedTaskIDs: collapsedTaskIDs,
                actions: actions
            )
        }
    }

    // MARK: - Selection

    private func selectTask(_ taskID: String) {
        guard selectedTaskID != taskID else { return }
        selectedTaskID = taskID
        view.window?.makeFirstResponder(view)
        render(tasks: store.tasks)
    }

    private func clearSelection() {
        guard selectedTaskID != nil else { return }
        selectedTaskID = nil
        render(tasks: store.tasks)
    }

    private func toggleExpanded(taskID: String) {
        // Just record the state for future re-renders; the row animates
        // its own expansion in place.
        if collapsedTaskIDs.contains(taskID) {
            collapsedTaskIDs.remove(taskID)
        } else {
            collapsedTaskIDs.insert(taskID)
        }
    }

    // MARK: - Deletion

    private func confirmAndDeleteSelectedTask() {
        guard let taskID = selectedTaskID,
              let task = store.task(id: taskID),
              let window = view.window else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Delete Task?"
        alert.informativeText = "\u{201C}\(task.title)\u{201D} will be deleted. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")   // default button — Enter confirms
        alert.addButton(withTitle: "Cancel")   // Esc cancels

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.selectedTaskID = nil
            self?.store.deleteTask(id: taskID)
        }
    }

    // MARK: - Shortcuts

    private func installCommandNShortcutIfNeeded() {
        guard !didInstallCommandN else { return }
        guard let mainMenu = NSApp.mainMenu,
              let fileMenuItem = mainMenu.item(withTitle: "File"),
              let fileMenu = fileMenuItem.submenu,
              let newItem = fileMenu.items.first(where: {
                  $0.keyEquivalent.lowercased() == "n" && $0.keyEquivalentModifierMask.contains(.command)
              }) else {
            return
        }

        newItem.title = "New Task"
        newItem.target = self
        newItem.action = #selector(handleAddTaskAction(_:))
        didInstallCommandN = true
    }

    @objc
    private func handleAddTaskAction(_ sender: Any?) {
        presentAddTaskDialog()
    }

    // MARK: - Sheets

    private func presentAddTaskDialog(preselected: Quadrant = .q1) {
        let form = TaskFormViewController(mode: .create(preselected))
        form.onSubmit = { [weak self] title, quadrant, dueDate in
            self?.store.addTask(title: title, quadrant: quadrant, dueDate: dueDate)
        }
        presentAsSheet(form)
    }

    private func presentEditTaskDialog(taskID: String) {
        guard let task = store.task(id: taskID) else { return }

        let form = TaskFormViewController(mode: .edit(task))
        form.onSubmit = { [weak self] title, quadrant, dueDate in
            self?.store.updateTitle(id: taskID, newTitle: title)
            if quadrant != task.quadrant {
                self?.store.moveTask(id: taskID, to: quadrant)
            }
            if dueDate != task.dueDate {
                self?.store.updateDueDate(id: taskID, dueDate: dueDate)
            }
        }
        presentAsSheet(form)
    }

    private func presentAddSubtaskDialog(taskID: String) {
        guard let task = store.task(id: taskID) else { return }

        let form = TaskFormViewController(mode: .subtask(parentTitle: task.title, existing: nil))
        form.onSubmit = { [weak self] title, _, _ in
            self?.collapsedTaskIDs.remove(taskID)
            self?.store.addSubtask(taskID: taskID, title: title)
        }
        presentAsSheet(form)
    }

    private func presentEditSubtaskDialog(taskID: String, subtaskID: String) {
        guard let task = store.task(id: taskID),
              let subtask = task.subtasks.first(where: { $0.id == subtaskID }) else {
            return
        }

        let form = TaskFormViewController(mode: .subtask(parentTitle: task.title, existing: subtask))
        form.onSubmit = { [weak self] title, _, _ in
            self?.store.updateSubtaskTitle(taskID: taskID, subtaskID: subtaskID, newTitle: title)
        }
        presentAsSheet(form)
    }
}
