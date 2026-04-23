//
//  SettingsWindow.swift
//  BriteLog
//
//  Created by Gale Williams on 4/22/26.
//

import BriteLogCore
import SwiftUI

struct SettingsWindow: View {
    @Environment(BriteLogAppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.title3.weight(.semibold))

            Text("These settings are now stored in the app's Application Support directory so the app can own project integration and viewer preferences.")
                .foregroundStyle(.secondary)

            Picker("Default theme", selection: selectedThemeBinding) {
                ForEach(BriteLogTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName)
                        .tag(theme)
                }
            }
            .pickerStyle(.menu)

            Toggle("Show the viewer when BriteLog is triggered from project integration", isOn: showViewerOnLaunchBinding)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    private var selectedThemeBinding: Binding<BriteLogTheme> {
        Binding(
            get: { model.configuration.selectedTheme },
            set: { model.setSelectedTheme($0) },
        )
    }

    private var showViewerOnLaunchBinding: Binding<Bool> {
        Binding(
            get: { model.configuration.showViewerOnLaunch },
            set: { model.setShowViewerOnLaunch($0) },
        )
    }
}

#Preview {
    SettingsWindow()
        .environment(BriteLogAppModel())
}
