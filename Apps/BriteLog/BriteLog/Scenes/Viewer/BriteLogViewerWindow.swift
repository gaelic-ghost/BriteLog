import BriteLogCore
import SwiftUI

struct BriteLogViewerWindow: View {
    @Environment(BriteLogAppModel.self) private var model

    @State private var newRuleName = ""
    @State private var newRuleMatchText = ""
    @State private var newRuleSubsystem = ""
    @State private var newRuleCategory = ""
    @State private var newRuleMinimumLevel: BriteLogRecord.Level?

    private var viewerSearchTextBinding: Binding<String> {
        Binding(
            get: { model.viewerPreferences.searchText },
            set: { model.setViewerSearchText($0) },
        )
    }

    private var viewerHighlightTextBinding: Binding<String> {
        Binding(
            get: { model.viewerPreferences.highlightText },
            set: { model.setViewerHighlightText($0) },
        )
    }

    private var viewerMinimumLevelBinding: Binding<BriteLogRecord.Level?> {
        Binding(
            get: { model.viewerPreferences.minimumLevel },
            set: { model.setViewerMinimumLevel($0) },
        )
    }

    private var viewerMetadataModeBinding: Binding<BriteLogMetadataMode> {
        Binding(
            get: { model.viewerPreferences.metadataMode },
            set: { model.setViewerMetadataMode($0) },
        )
    }

    private var viewerLevelOptions: [BriteLogRecord.Level] {
        [
            .trace,
            .debug,
            .info,
            .notice,
            .warning,
            .error,
            .fault,
            .critical,
        ]
    }

    private var viewerSubtitle: String {
        guard let request = model.viewerSession.request else {
            return "Waiting for a debug-run request from Xcode project integration."
        }

        return "Watching \(request.bundleIdentifier) with \(model.viewerSession.records.count) buffered records in the current session."
    }

    var body: some View {
        let viewerRows = BriteLogViewerPresentation.rows(
            from: model.viewerSession.records,
            preferences: model.viewerPreferences,
            highlightRules: model.highlightRules,
        )

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Live Log Viewer")
                    .font(.title2.weight(.semibold))

                Text(viewerSubtitle)
                    .foregroundStyle(.secondary)
            }

            viewerControls
            savedHighlightRulesSection

            if model.viewerSession.records.isEmpty {
                ContentUnavailableView(
                    "No Live Records Yet",
                    systemImage: "text.badge.xmark",
                    description: Text(
                        "Once the targeted app emits unified log entries for its bundle identifier, BriteLog will buffer them here.",
                    ),
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewerRows.isEmpty {
                ContentUnavailableView(
                    "All Records Are Filtered Out",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(
                        "The current search text or minimum level hides every buffered record. Adjust those controls to widen the visible log surface.",
                    ),
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(viewerRows) {
                    TableColumn("Time") { row in
                        Text(row.timestampText)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 88, ideal: 96, max: 112)

                    TableColumn("Level") { row in
                        Text(row.record.level.rawValue.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                BriteLogViewerPresentation.levelColor(
                                    for: row.record.level,
                                    theme: model.configuration.selectedTheme,
                                ),
                            )
                    }
                    .width(min: 70, ideal: 82, max: 94)

                    TableColumn("Source") { row in
                        VStack(alignment: .leading, spacing: 2) {
                            if !row.sourceText.isEmpty {
                                Text(row.sourceText)
                                    .font(.caption)
                            } else {
                                Text("Hidden")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let detailsText = row.detailsText {
                                Text(detailsText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .width(min: 180, ideal: 240, max: 340)

                    TableColumn("Message") { row in
                        VStack(alignment: .leading, spacing: 4) {
                            if !row.matchedRuleNames.isEmpty {
                                Text("Matched rules: \(row.matchedRuleNames.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(row.record.message)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    BriteLogViewerPresentation.highlightBackground(
                                        theme: model.configuration.selectedTheme,
                                        isHighlighted: row.isHighlighted,
                                    ),
                                ),
                        )
                    }
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 960, minHeight: 420, alignment: .topLeading)
        .padding(20)
        .searchable(text: viewerSearchTextBinding, placement: .toolbar, prompt: "Filter buffered logs")
    }

    private var viewerControls: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Minimum level")
                    .font(.caption.weight(.semibold))
                Picker("Minimum level", selection: viewerMinimumLevelBinding) {
                    Text("All")
                        .tag(BriteLogRecord.Level?.none)

                    ForEach(viewerLevelOptions, id: \.self) { level in
                        Text(level.rawValue.uppercased())
                            .tag(BriteLogRecord.Level?.some(level))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Metadata")
                    .font(.caption.weight(.semibold))
                Picker("Metadata", selection: viewerMetadataModeBinding) {
                    Text("Hidden").tag(BriteLogMetadataMode.hidden)
                    Text("Compact").tag(BriteLogMetadataMode.compact)
                    Text("Full").tag(BriteLogMetadataMode.full)
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Highlight text")
                    .font(.caption.weight(.semibold))
                TextField("Highlight records containing…", text: viewerHighlightTextBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 220)
            }

            Spacer(minLength: 0)
        }
    }

    private var savedHighlightRulesSection: some View {
        DisclosureGroup("Saved Highlight Rules") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Saved rules are stored with the app’s configuration and automatically re-apply when future debug sessions stream matching records.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if model.highlightRules.isEmpty {
                    Text("No saved highlight rules yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.highlightRules) { rule in
                        HStack(alignment: .top, spacing: 12) {
                            Toggle(
                                isOn: Binding(
                                    get: { rule.isEnabled },
                                    set: { model.setHighlightRuleEnabled(ruleID: rule.id, isEnabled: $0) },
                                ),
                            ) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rule.trimmedName)
                                        .font(.subheadline.weight(.semibold))
                                    Text(rule.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.checkbox)

                            Spacer(minLength: 0)

                            Button("Delete", role: .destructive) {
                                model.removeHighlightRule(ruleID: rule.id)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("New Highlight Rule")
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 12) {
                        TextField("Rule name", text: $newRuleName)
                        TextField("Match text", text: $newRuleMatchText)
                    }

                    HStack(spacing: 12) {
                        TextField("Subsystem (optional)", text: $newRuleSubsystem)
                        TextField("Category (optional)", text: $newRuleCategory)

                        Picker("Minimum level", selection: $newRuleMinimumLevel) {
                            Text("Any level")
                                .tag(BriteLogRecord.Level?.none)

                            ForEach(viewerLevelOptions, id: \.self) { level in
                                Text(level.rawValue.uppercased())
                                    .tag(BriteLogRecord.Level?.some(level))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 180)
                    }

                    HStack {
                        Button("Save Rule") {
                            model.addHighlightRule(
                                name: newRuleName,
                                matchText: newRuleMatchText,
                                subsystem: newRuleSubsystem,
                                category: newRuleCategory,
                                minimumLevel: newRuleMinimumLevel,
                            )

                            if model.lastErrorDescription == nil {
                                resetNewRuleFields()
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func resetNewRuleFields() {
        newRuleName = ""
        newRuleMatchText = ""
        newRuleSubsystem = ""
        newRuleCategory = ""
        newRuleMinimumLevel = nil
    }
}

#Preview {
    BriteLogViewerWindow()
        .environment(BriteLogAppModel())
}
