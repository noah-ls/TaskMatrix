//
//  AppDelegate.swift
//  TaskMatrix
//
//  Created by 123 on 4/9/26.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // The UI uses a fixed light palette; keep system dark mode from mixing in.
        NSApp.appearance = NSAppearance(named: .aqua)
        configureAppMenu()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    private func configureAppMenu() {
        guard let appMenu = NSApp.mainMenu?.items.first?.submenu,
              let settingsItem = appMenu.items.first(where: {
                  $0.keyEquivalent == ","
              }) else {
            return
        }

        settingsItem.title = "Settings…"
        settingsItem.target = self
        settingsItem.action = #selector(handleShowSettings(_:))
    }

    @objc
    private func handleShowSettings(_ sender: Any?) {
        mainViewController()?.showSettingsWindow()
    }

    private func mainViewController() -> ViewController? {
        NSApp.windows.compactMap { $0.contentViewController as? ViewController }.first
    }
}
