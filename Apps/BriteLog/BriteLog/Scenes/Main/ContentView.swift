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
    @Environment(\.openWindow) private var openWindow

    @State private var autoOpenedViewerRequestID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("BriteLog", systemImage: "text.badge.star")
                .font(.title2.weight(.semibold))

            Text("A signed macOS host for the shared BriteLog engine")
                .font(.headline)

            Text("This app now owns app-level configuration, project integration records, and a dedicated utility viewer window for a targeted debug run.")
                .foregroundStyle(.secondary)

            GroupBox("Current App State") {
                VStack(alignment: .leading, spacing: 10) {
                    labeledValue("Default theme", value: model.configuration.selectedTheme.displayName)
                    labeledValue("Show viewer on launch", value: model.configuration.showViewerOnLaunch ? "Enabled" : "Disabled")
                    labeledValue("Application Support", value: model.applicationSupportPath)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Viewer Session") {
                VStack(alignment: .leading, spacing: 10) {
                    labeledValue("Session state", value: model.viewerSession.state.displayName)
                    labeledValue("Buffered records", value: "\(model.viewerSession.records.count)")

                    if let createdAt = model.viewerSession.request.map({ _ in model.viewerSession.createdAt }) {
                        labeledValue("Started", value: createdAt.formatted(date: .abbreviated, time: .standard))
                    }

                    if let endedAt = model.viewerSession.endedAt {
                        labeledValue("Ended", value: endedAt.formatted(date: .abbreviated, time: .standard))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Log Viewer Window") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("The live log surface now lives in a dedicated floating utility window so it can stay visible while you work in Xcode or the target app.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        labeledValue("Window behavior", value: "Floating utility window")
                        labeledValue("Auto-open on run", value: model.configuration.showViewerOnLaunch ? "Enabled" : "Disabled")
                        labeledValue("Buffered records", value: "\(model.viewerSession.records.count)")
                        labeledValue("Keyboard shortcut", value: "Command-Shift-L")
                    }

                    Button("Open Log Viewer") {
                        openViewerWindow()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            GroupBox("Current Run Request") {
                if let viewerRequest = model.viewerSession.request {
                    VStack(alignment: .leading, spacing: 10) {
                        labeledValue("Bundle identifier", value: viewerRequest.bundleIdentifier)
                        labeledValue("Scheme", value: viewerRequest.schemeName)
                        labeledValue("Build configuration", value: viewerRequest.buildConfiguration)
                        labeledValue("Source", value: viewerRequest.source.rawValue)
                        labeledValue("Project", value: viewerRequest.projectPath)

                        if let builtProductPath = viewerRequest.builtProductPath, !builtProductPath.isEmpty {
                            labeledValue("Built product", value: builtProductPath)
                        }

                        if let observedApplication = model.viewerSession.observedApplication {
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
                    Text("No incoming debug-run request has been received yet. Once a scheme pre-action writes a fresh request, the app will persist it here, open a viewer session, and watch for launch and terminate events for that bundle identifier.")
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

                                if let schemePath = install.schemePath, !schemePath.isEmpty {
                                    Text("Scheme file: \(schemePath)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }

                                if let backupPath = install.backupPath, !backupPath.isEmpty {
                                    Text("Latest backup: \(backupPath)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
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
        .onAppear {
            maybeAutoOpenViewer()
        }
        .onChange(of: model.viewerSession.request?.id) { _, _ in
            maybeAutoOpenViewer()
        }
        .onChange(of: model.configuration.showViewerOnLaunch) { _, _ in
            maybeAutoOpenViewer()
        }
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

    private func maybeAutoOpenViewer() {
        guard model.configuration.showViewerOnLaunch else {
            return
        }
        guard let requestID = model.viewerSession.request?.id else {
            return
        }
        guard autoOpenedViewerRequestID != requestID else {
            return
        }

        openViewerWindow()
        autoOpenedViewerRequestID = requestID
    }

    private func openViewerWindow() {
        openWindow(id: BriteLogWindowID.viewer)
    }
}

#Preview {
    ContentView()
        .environment(BriteLogAppModel())
}
