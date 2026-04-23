//
//  ContentView.swift
//  BriteLog
//
//  Created by Gale Williams on 4/22/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("BriteLog", systemImage: "text.badge.star")
                .font(.title2.weight(.semibold))

            Text("A signed macOS host for the shared BriteLog engine.")
                .font(.headline)

            Text("The package CLI still drives the log watching behavior today. This app is the entitlement-bearing home for settings, persisted data, and the future live log viewer.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Next up")
                    .font(.subheadline.weight(.semibold))
                Text("Connect the app to the shared logging engine, persist app-owned data in Application Support, and grow this window into the real viewer surface.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }
}

#Preview {
    ContentView()
}
