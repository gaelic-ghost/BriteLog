//
//  SettingsWindow.swift
//  BriteLog
//
//  Created by Gale Williams on 4/22/26.
//

import SwiftUI

struct SettingsWindow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.title3.weight(.semibold))

            Text("This is the future home for default theme selection, saved watch profiles, highlight rules, and other app-owned preferences.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }
}

#Preview {
    SettingsWindow()
}
