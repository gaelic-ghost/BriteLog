//
//  ContentView.swift
//  BriteLog
//
//  Created by Gale Williams on 4/22/26.
//

import BriteLogCore
import SwiftUI

struct ContentView: View {
    @Environment(BriteLogAppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("BriteLog", systemImage: "text.badge.star")
                .font(.title2.weight(.semibold))

            Text("A signed macOS host for the shared BriteLog engine")
                .font(.headline)

            Text("This app now owns app-level configuration and project install records in Application Support. The next step is connecting those records to the first real viewer and Xcode integration flow.")
                .foregroundStyle(.secondary)

            GroupBox("Current App State") {
                VStack(alignment: .leading, spacing: 10) {
                    labeledValue("Default theme", value: model.configuration.selectedTheme.displayName)
                    labeledValue("Show viewer on launch", value: model.configuration.showViewerOnLaunch ? "Enabled" : "Disabled")
                    labeledValue("Application Support", value: model.applicationSupportPath)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Current Run Request") {
                if let currentRunRequest = model.currentRunRequest {
                    VStack(alignment: .leading, spacing: 10) {
                        labeledValue("Bundle identifier", value: currentRunRequest.bundleIdentifier)
                        labeledValue("Scheme", value: currentRunRequest.schemeName)
                        labeledValue("Build configuration", value: currentRunRequest.buildConfiguration)
                        labeledValue("Source", value: currentRunRequest.source.rawValue)
                        labeledValue("Project", value: currentRunRequest.projectPath)

                        if let builtProductPath = currentRunRequest.builtProductPath, !builtProductPath.isEmpty {
                            labeledValue("Built product", value: builtProductPath)
                        }

                        if let observedApplication = model.observedApplication {
                            labeledValue("Observed phase", value: observedApplication.phase.rawValue)
                            if let localizedName = observedApplication.localizedName, !localizedName.isEmpty {
                                labeledValue("Observed app", value: localizedName)
                            }
                            if let processIdentifier = observedApplication.processIdentifier {
                                labeledValue("Observed PID", value: String(processIdentifier))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No incoming debug-run request has been received yet. Once a scheme pre-action writes a fresh request, the app will persist it here and watch for launch and terminate events for that bundle identifier.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            ProjectIntegrationInstallerSection()

            GroupBox("Project Integrations") {
                if model.projectInstalls.isEmpty {
                    Text("No project integration records yet. This is where build-plugin and scheme-install state will appear once the installer flow lands.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(model.projectInstalls) { install in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(install.displayName)
                                    .font(.headline)
                                Text(install.integrationKind.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text(install.projectPath)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)

                                if let schemeName = install.schemeName {
                                    Text("Scheme: \(schemeName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let bundleIdentifier = install.bundleIdentifier, !bundleIdentifier.isEmpty {
                                    Text("Bundle ID: \(bundleIdentifier)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let notes = install.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let lastErrorDescription = model.lastErrorDescription {
                Text("Storage warning: \(lastErrorDescription)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    private func labeledValue(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    ContentView()
        .environment(BriteLogAppModel())
}
