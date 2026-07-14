import Cocoa

/// Sheet used for creating and editing tasks and subtasks, styled to match
/// the matrix.
final class TaskFormViewController: NSViewController, NSTextFieldDelegate {
    enum Mode {
        case create(Quadrant)
        case edit(TaskItem)
        case subtask(parentTitle: String, existing: SubTask?)
    }

    var onSubmit: ((String, Quadrant, Date?) -> Void)?

    private let mode: Mode
    private var selectedQuadrant: Quadrant
    private var optionViews: [QuadrantOptionView] = []
    private let showsQuadrantPicker: Bool

    private let titleField = NSTextField()
    private let pickerView = QuadrantPickerView()
    private var submitButton: PillButton?
    private var dueDateCheckbox: NSButton?
    private var dueDatePicker: NSDatePicker?

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create(let quadrant):
            selectedQuadrant = quadrant
            showsQuadrantPicker = true
        case .edit(let task):
            selectedQuadrant = task.quadrant
            showsQuadrantPicker = true
        case .subtask:
            selectedQuadrant = .q1   // unused; subtasks live inside their parent
            showsQuadrantPicker = false
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 320))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.taskCanvas.cgColor

        let heading: String
        let subheading: String
        let submitTitle: String
        var initialTitle = ""
        var initialDueDate: Date?

        switch mode {
        case .create:
            heading = "New Task"
            subheading = "Give it a clear title and pick where it belongs."
            submitTitle = "Create Task"
        case .edit(let task):
            heading = "Edit Task"
            subheading = "Update the title or move it to another quadrant."
            submitTitle = "Save Changes"
            initialTitle = task.title
            initialDueDate = task.dueDate
        case .subtask(let parentTitle, let existing):
            heading = existing == nil ? "New Subtask" : "Edit Subtask"
            subheading = "for \u{201C}\(parentTitle)\u{201D}"
            submitTitle = existing == nil ? "Add Subtask" : "Save Changes"
            initialTitle = existing?.title ?? ""
        }

        let headingLabel = NSTextField(labelWithString: heading)
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        headingLabel.font = .systemFont(ofSize: 17, weight: .black)
        headingLabel.textColor = NSColor.taskInk

        let subheadingLabel = NSTextField(labelWithString: subheading)
        subheadingLabel.translatesAutoresizingMaskIntoConstraints = false
        subheadingLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subheadingLabel.textColor = NSColor.taskMuted
        subheadingLabel.lineBreakMode = .byTruncatingTail
        subheadingLabel.maximumNumberOfLines = 1

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.placeholderString = showsQuadrantPicker ? "Task title" : "Subtask title"
        titleField.font = .systemFont(ofSize: 14, weight: .medium)
        titleField.bezelStyle = .roundedBezel
        titleField.controlSize = .large
        titleField.delegate = self
        titleField.stringValue = initialTitle

        let quadrantLabel = NSTextField(labelWithString: "")
        quadrantLabel.translatesAutoresizingMaskIntoConstraints = false
        let quadrantText = NSMutableAttributedString(string: "QUADRANT")
        quadrantText.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.taskMuted,
                .kern: 0.8
            ],
            range: NSRange(location: 0, length: quadrantText.length)
        )
        quadrantLabel.attributedStringValue = quadrantText

        let optionTopRow = NSStackView()
        optionTopRow.translatesAutoresizingMaskIntoConstraints = false
        optionTopRow.orientation = .horizontal
        optionTopRow.distribution = .fillEqually
        optionTopRow.spacing = 8

        let optionBottomRow = NSStackView()
        optionBottomRow.translatesAutoresizingMaskIntoConstraints = false
        optionBottomRow.orientation = .horizontal
        optionBottomRow.distribution = .fillEqually
        optionBottomRow.spacing = 8

        for quadrant in Quadrant.allCases {
            let option = QuadrantOptionView(quadrant: quadrant)
            option.onSelect = { [weak self] chosen in
                self?.selectQuadrant(chosen)
            }
            optionViews.append(option)
            (quadrant == .q1 || quadrant == .q2 ? optionTopRow : optionBottomRow).addArrangedSubview(option)
        }

        let optionsStack = NSStackView(views: [optionTopRow, optionBottomRow])
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.orientation = .vertical
        optionsStack.alignment = .leading
        optionsStack.spacing = 8

        pickerView.addSubview(optionsStack)
        pickerView.onCycleSelection = { [weak self] delta in
            self?.cycleQuadrant(by: delta)
        }
        pickerView.onFocusPrevious = { [weak self] in
            guard let self else { return }
            self.view.window?.makeFirstResponder(self.titleField)
        }

        // Due date — optional, date only.
        let dueDateLabel = NSTextField(labelWithString: "")
        dueDateLabel.translatesAutoresizingMaskIntoConstraints = false
        let dueDateText = NSMutableAttributedString(string: "DUE DATE")
        dueDateText.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.taskMuted,
                .kern: 0.8
            ],
            range: NSRange(location: 0, length: dueDateText.length)
        )
        dueDateLabel.attributedStringValue = dueDateText

        let checkbox = NSButton(checkboxWithTitle: "Set due date", target: self, action: #selector(handleDueDateToggle(_:)))
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.font = .systemFont(ofSize: 12, weight: .medium)
        checkbox.contentTintColor = NSColor.taskAccentText
        checkbox.state = initialDueDate == nil ? .off : .on
        dueDateCheckbox = checkbox

        let datePicker = NSDatePicker()
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.datePickerElements = .yearMonthDay
        datePicker.dateValue = initialDueDate ?? Date()
        datePicker.isEnabled = initialDueDate != nil
        dueDatePicker = datePicker

        let dueDateSpacer = NSView()
        dueDateSpacer.translatesAutoresizingMaskIntoConstraints = false
        dueDateSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        dueDateSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let dueDateRow = NSStackView(views: [checkbox, datePicker, dueDateSpacer])
        dueDateRow.translatesAutoresizingMaskIntoConstraints = false
        dueDateRow.orientation = .horizontal
        dueDateRow.alignment = .centerY
        dueDateRow.spacing = 10

        let cancelButton = PillButton(
            title: "Cancel",
            style: .subtle,
            target: self,
            action: #selector(handleCancel(_:))
        )
        cancelButton.keyEquivalent = "\u{1b}"

        let submit = PillButton(
            title: submitTitle,
            target: self,
            action: #selector(handleSubmit(_:))
        )
        submit.keyEquivalent = "\r"
        submitButton = submit

        let buttonSpacer = NSView()
        buttonSpacer.translatesAutoresizingMaskIntoConstraints = false
        buttonSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        buttonSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let buttonRow = NSStackView(views: [buttonSpacer, cancelButton, submit])
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        view.addSubview(headingLabel)
        view.addSubview(subheadingLabel)
        view.addSubview(titleField)
        if showsQuadrantPicker {
            view.addSubview(quadrantLabel)
            view.addSubview(pickerView)
            view.addSubview(dueDateLabel)
            view.addSubview(dueDateRow)
        }
        view.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 440),

            headingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headingLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),

            subheadingLabel.leadingAnchor.constraint(equalTo: headingLabel.leadingAnchor),
            subheadingLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            subheadingLabel.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 2),

            titleField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            titleField.topAnchor.constraint(equalTo: subheadingLabel.bottomAnchor, constant: 14),

            buttonRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonRow.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18)
        ])

        if showsQuadrantPicker {
            NSLayoutConstraint.activate([
                quadrantLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                quadrantLabel.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 16),

                pickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
                pickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
                pickerView.topAnchor.constraint(equalTo: quadrantLabel.bottomAnchor, constant: 3),

                optionsStack.leadingAnchor.constraint(equalTo: pickerView.leadingAnchor, constant: 5),
                optionsStack.trailingAnchor.constraint(equalTo: pickerView.trailingAnchor, constant: -5),
                optionsStack.topAnchor.constraint(equalTo: pickerView.topAnchor, constant: 5),
                optionsStack.bottomAnchor.constraint(equalTo: pickerView.bottomAnchor, constant: -5),

                optionTopRow.widthAnchor.constraint(equalTo: optionsStack.widthAnchor),
                optionBottomRow.widthAnchor.constraint(equalTo: optionsStack.widthAnchor),

                dueDateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                dueDateLabel.topAnchor.constraint(equalTo: pickerView.bottomAnchor, constant: 14),

                dueDateRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                dueDateRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                dueDateRow.topAnchor.constraint(equalTo: dueDateLabel.bottomAnchor, constant: 7),

                buttonRow.topAnchor.constraint(equalTo: dueDateRow.bottomAnchor, constant: 14)
            ])
        } else {
            buttonRow.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 18).isActive = true
        }

        selectQuadrant(selectedQuadrant)
        refreshSubmitEnabled()

        // Size the sheet from the constraint chain; the subtask variant is
        // much shorter than the task variant with its quadrant picker.
        preferredContentSize = view.fittingSize
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // Tab from the title focuses the picker; keep AppKit from
        // recalculating the loop and bypassing it.
        if showsQuadrantPicker {
            view.window?.autorecalculatesKeyViewLoop = false
            titleField.nextKeyView = pickerView
            pickerView.nextKeyView = titleField
        }

        view.window?.makeFirstResponder(titleField)
    }

    func controlTextDidChange(_ obj: Notification) {
        refreshSubmitEnabled()
    }

    private func selectQuadrant(_ quadrant: Quadrant) {
        selectedQuadrant = quadrant
        for option in optionViews {
            option.isChosen = option.quadrant == quadrant
        }
    }

    private func cycleQuadrant(by delta: Int) {
        let all = Quadrant.allCases
        guard let index = all.firstIndex(of: selectedQuadrant) else { return }
        let next = (index + delta + all.count) % all.count
        selectQuadrant(all[next])
    }

    private func refreshSubmitEnabled() {
        let trimmed = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        submitButton?.isEnabled = !trimmed.isEmpty
    }

    @objc
    private func handleDueDateToggle(_ sender: NSButton) {
        dueDatePicker?.isEnabled = sender.state == .on
    }

    @objc
    private func handleCancel(_ sender: Any?) {
        dismiss(self)
    }

    @objc
    private func handleSubmit(_ sender: Any?) {
        let trimmed = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var dueDate: Date?
        if showsQuadrantPicker,
           dueDateCheckbox?.state == .on,
           let picked = dueDatePicker?.dateValue {
            dueDate = Calendar.current.startOfDay(for: picked)
        }

        onSubmit?(trimmed, selectedQuadrant, dueDate)
        dismiss(self)
    }
}
