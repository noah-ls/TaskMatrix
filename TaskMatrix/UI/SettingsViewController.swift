import Cocoa

final class SettingsViewController: NSViewController, NSTextFieldDelegate {
    var onAutoArchiveDaysChanged: ((Int) -> Void)?

    private let daysField = NSTextField()
    private let stepper = NSStepper()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 430, height: 190))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.taskCanvas.cgColor

        let titleLabel = NSTextField(labelWithString: "Settings")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 20, weight: .black)
        titleLabel.textColor = NSColor.taskInk

        let sectionLabel = NSTextField(labelWithString: "AUTO-ARCHIVE")
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false
        let sectionText = NSMutableAttributedString(string: sectionLabel.stringValue)
        sectionText.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.taskMuted,
                .kern: 0.8
            ],
            range: NSRange(location: 0, length: sectionText.length)
        )
        sectionLabel.attributedStringValue = sectionText

        let descriptionLabel = NSTextField(labelWithString: "Archive completed tasks after they have been done for:")
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        descriptionLabel.textColor = NSColor.taskInk

        daysField.translatesAutoresizingMaskIntoConstraints = false
        daysField.alignment = .right
        daysField.bezelStyle = .roundedBezel
        daysField.controlSize = .large
        daysField.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        daysField.delegate = self

        stepper.translatesAutoresizingMaskIntoConstraints = false
        stepper.minValue = 1
        stepper.maxValue = 365
        stepper.increment = 1
        stepper.target = self
        stepper.action = #selector(handleStepper(_:))

        let daysLabel = NSTextField(labelWithString: "days")
        daysLabel.translatesAutoresizingMaskIntoConstraints = false
        daysLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        daysLabel.textColor = NSColor.taskMuted

        let defaultLabel = NSTextField(labelWithString: "Default: 15 days")
        defaultLabel.translatesAutoresizingMaskIntoConstraints = false
        defaultLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
        defaultLabel.textColor = NSColor.taskMuted

        view.addSubview(titleLabel)
        view.addSubview(sectionLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(daysField)
        view.addSubview(stepper)
        view.addSubview(daysLabel)
        view.addSubview(defaultLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),

            sectionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            sectionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 22),

            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            descriptionLabel.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 8),

            daysField.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            daysField.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            daysField.widthAnchor.constraint(equalToConstant: 72),

            stepper.leadingAnchor.constraint(equalTo: daysField.trailingAnchor, constant: 7),
            stepper.centerYAnchor.constraint(equalTo: daysField.centerYAnchor),

            daysLabel.leadingAnchor.constraint(equalTo: stepper.trailingAnchor, constant: 8),
            daysLabel.centerYAnchor.constraint(equalTo: daysField.centerYAnchor),

            defaultLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            defaultLabel.topAnchor.constraint(equalTo: daysField.bottomAnchor, constant: 10),
            defaultLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -18)
        ])

        updateControls(days: AppSettings.autoArchiveDays)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitFieldValue()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 {
            commitFieldValue()
            return
        }
        super.keyDown(with: event)
    }

    private func updateControls(days: Int) {
        daysField.stringValue = "\(days)"
        stepper.integerValue = days
    }

    private func commitFieldValue() {
        let days = AppSettings.clamped(daysField.integerValue)
        AppSettings.autoArchiveDays = days
        updateControls(days: days)
        onAutoArchiveDaysChanged?(days)
    }

    @objc
    private func handleStepper(_ sender: NSStepper) {
        let days = AppSettings.clamped(sender.integerValue)
        AppSettings.autoArchiveDays = days
        updateControls(days: days)
        onAutoArchiveDaysChanged?(days)
    }
}
