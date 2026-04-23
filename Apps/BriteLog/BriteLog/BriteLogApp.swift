//
//  BriteLogApp.swift
//  BriteLog
//
//  Created by Gale Williams on 4/22/26.
//

import SwiftUI

@available(macOS 10.15, *)
@main
struct BriteLogApp: App {
    @State private var model = BriteLogAppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        UtilityWindow("Log Viewer", id: BriteLogWindowID.viewer) {
            BriteLogViewerWindow()
                .environment(model)
        }
        .defaultSize(width: 1200, height: 720)
        .windowLevel(.floating)
        .restorationBehavior(.disabled)
        .keyboardShortcut("l", modifiers: [.command, .shift])
        Settings {
            SettingsWindow()
                .environment(model)
        }
    }
}
