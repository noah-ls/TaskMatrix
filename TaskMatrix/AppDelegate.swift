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
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

