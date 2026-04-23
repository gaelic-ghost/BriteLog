//
//  BriteLogApp.swift
//  BriteLog
//
//  Created by Gale Williams on 4/22/26.
//

import SwiftUI
import BriteLogCLI

@available(macOS 10.15, *)
@main
struct BriteLogApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
		Settings {
			SettingsWindow()
		}
    }
}

enum BriteLogToolExecutable {
	static func main() {
		runBriteLogCLI()
	}
}
