import Cocoa

/// Presents a CalendarPickerView in a transient popover anchored to any
/// view — the calendar lives outside the layout that summons it.
final class CalendarPopover {
    private static var activePopover: NSPopover?

    static func show(from anchorView: NSView, selectedDate: Date?, onSelect: @escaping (Date) -> Void) {
        let calendarView = CalendarPickerView()
        calendarView.selectedDate = selectedDate

        let container = NSView()
        container.addSubview(calendarView)
        NSLayoutConstraint.activate([
            calendarView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            calendarView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            calendarView.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            calendarView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6)
        ])

        let contentController = NSViewController()
        contentController.view = container

        let popover = NSPopover()
        popover.contentViewController = contentController
        popover.contentSize = container.fittingSize
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .aqua)

        calendarView.onDateSelected = { [weak popover] date in
            popover?.performClose(nil)
            onSelect(date)
        }

        activePopover = popover
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
    }
}
