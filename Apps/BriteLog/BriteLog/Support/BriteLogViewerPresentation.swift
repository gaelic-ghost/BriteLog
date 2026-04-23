import BriteLogCore
import SwiftUI

enum BriteLogViewerPresentation {
    struct Row: Identifiable, Equatable {
        var id: String
        var record: BriteLogRecord
        var timestampText: String
        var sourceText: String
        var detailsText: String?
        var isHighlighted: Bool
        var matchedRuleNames: [String]
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func rows(
        from records: [BriteLogRecord],
        preferences: BriteLogViewerPreferences,
        highlightRules: [BriteLogHighlightRule] = [],
    ) -> [Row] {
        records.enumerated().compactMap { index, record in
            guard matches(record, preferences: preferences) else {
                return nil
            }

            let matchedRuleNames = highlightRules
                .filter { $0.matches(record) }
                .map(\.trimmedName)
                .filter { !$0.isEmpty }

            return Row(
                id: rowID(for: record, index: index),
                record: record,
                timestampText: timestampFormatter.string(from: record.date),
                sourceText: sourceText(for: record, metadataMode: preferences.metadataMode),
                detailsText: detailsText(for: record, metadataMode: preferences.metadataMode),
                isHighlighted: isHighlighted(record, text: preferences.highlightText) || !matchedRuleNames.isEmpty,
                matchedRuleNames: matchedRuleNames,
            )
        }
    }

    static func levelColor(
        for level: BriteLogRecord.Level,
        theme: BriteLogTheme,
    ) -> Color {
        switch (theme, level) {
            case (.plain, _):
                .primary
            case (.xcode, .trace):
                .gray
            case (.xcode, .debug):
                .teal
            case (.xcode, .info):
                .green
            case (.xcode, .notice):
                .blue
            case (.xcode, .warning):
                .orange
            case (.xcode, .error):
                .red
            case (.xcode, .fault):
                .purple
            case (.xcode, .critical):
                .red
            case (.xcode, .undefined):
                .secondary
            case (.neon, .trace):
                Color(red: 0.67, green: 0.75, blue: 1.0)
            case (.neon, .debug):
                Color(red: 0.12, green: 0.92, blue: 0.96)
            case (.neon, .info):
                Color(red: 0.48, green: 1.0, blue: 0.72)
            case (.neon, .notice):
                Color(red: 0.35, green: 0.75, blue: 1.0)
            case (.neon, .warning):
                Color(red: 1.0, green: 0.91, blue: 0.33)
            case (.neon, .error):
                Color(red: 1.0, green: 0.34, blue: 0.67)
            case (.neon, .fault):
                Color(red: 0.98, green: 0.42, blue: 0.98)
            case (.neon, .critical):
                Color(red: 1.0, green: 0.24, blue: 0.76)
            case (.neon, .undefined):
                .white
            case (.aurora, .trace):
                Color(red: 0.67, green: 0.78, blue: 0.72)
            case (.aurora, .debug):
                Color(red: 0.31, green: 0.86, blue: 0.72)
            case (.aurora, .info):
                Color(red: 0.58, green: 0.96, blue: 0.84)
            case (.aurora, .notice):
                Color(red: 0.64, green: 0.86, blue: 1.0)
            case (.aurora, .warning):
                Color(red: 1.0, green: 0.83, blue: 0.52)
            case (.aurora, .error):
                Color(red: 1.0, green: 0.66, blue: 0.76)
            case (.aurora, .fault):
                Color(red: 0.86, green: 0.62, blue: 0.98)
            case (.aurora, .critical):
                Color(red: 1.0, green: 0.48, blue: 0.74)
            case (.aurora, .undefined):
                Color(red: 0.82, green: 0.87, blue: 0.9)
            case (.ember, .trace):
                Color(red: 0.75, green: 0.72, blue: 0.68)
            case (.ember, .debug):
                Color(red: 0.89, green: 0.73, blue: 0.42)
            case (.ember, .info):
                Color(red: 0.72, green: 0.86, blue: 0.58)
            case (.ember, .notice):
                Color(red: 0.98, green: 0.67, blue: 0.36)
            case (.ember, .warning):
                Color(red: 1.0, green: 0.82, blue: 0.34)
            case (.ember, .error):
                Color(red: 1.0, green: 0.49, blue: 0.43)
            case (.ember, .fault):
                Color(red: 0.95, green: 0.41, blue: 0.72)
            case (.ember, .critical):
                Color(red: 0.98, green: 0.28, blue: 0.28)
            case (.ember, .undefined):
                Color(red: 0.9, green: 0.87, blue: 0.82)
            case (.ice, .trace):
                Color(red: 0.76, green: 0.87, blue: 1.0)
            case (.ice, .debug):
                Color(red: 0.54, green: 0.85, blue: 1.0)
            case (.ice, .info):
                Color(red: 0.48, green: 0.94, blue: 1.0)
            case (.ice, .notice):
                Color(red: 0.55, green: 0.85, blue: 1.0)
            case (.ice, .warning):
                Color(red: 1.0, green: 0.95, blue: 0.71)
            case (.ice, .error):
                Color(red: 1.0, green: 0.64, blue: 0.64)
            case (.ice, .fault):
                Color(red: 0.86, green: 0.74, blue: 1.0)
            case (.ice, .critical):
                Color(red: 1.0, green: 0.56, blue: 0.63)
            case (.ice, .undefined):
                Color(red: 0.87, green: 0.93, blue: 0.97)
        }
    }

    static func highlightBackground(
        theme: BriteLogTheme,
        isHighlighted: Bool,
    ) -> Color {
        guard isHighlighted else {
            return .clear
        }

        switch theme {
            case .plain:
                return Color.secondary.opacity(0.12)
            case .xcode:
                return Color.yellow.opacity(0.16)
            case .neon:
                return Color(red: 0.15, green: 0.08, blue: 0.22).opacity(0.72)
            case .aurora:
                return Color(red: 0.17, green: 0.24, blue: 0.28).opacity(0.72)
            case .ember:
                return Color(red: 0.24, green: 0.14, blue: 0.08).opacity(0.72)
            case .ice:
                return Color(red: 0.1, green: 0.18, blue: 0.26).opacity(0.72)
        }
    }

    private static func matches(
        _ record: BriteLogRecord,
        preferences: BriteLogViewerPreferences,
    ) -> Bool {
        if let minimumLevel = preferences.minimumLevel,
           record.level.rank < minimumLevel.rank {
            return false
        }

        let trimmedSearchText = preferences.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else {
            return true
        }

        let haystacks = [
            record.message,
            record.subsystem,
            record.category,
            record.process ?? "",
            record.sender ?? "",
            record.processIdentifier.map(String.init) ?? "",
        ]

        return haystacks.contains { $0.localizedCaseInsensitiveContains(trimmedSearchText) }
    }

    private static func isHighlighted(
        _ record: BriteLogRecord,
        text: String,
    ) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return false
        }

        return [
            record.message,
            record.subsystem,
            record.category,
            record.process ?? "",
            record.sender ?? "",
        ].contains { $0.localizedCaseInsensitiveContains(trimmedText) }
    }

    private static func sourceText(
        for record: BriteLogRecord,
        metadataMode: BriteLogMetadataMode,
    ) -> String {
        switch metadataMode {
            case .hidden:
                ""
            case .compact:
                [record.process, record.subsystem]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " • ")
            case .full:
                record.subsystem
        }
    }

    private static func detailsText(
        for record: BriteLogRecord,
        metadataMode: BriteLogMetadataMode,
    ) -> String? {
        switch metadataMode {
            case .hidden:
                return nil
            case .compact:
                var details: [String] = []
                if !record.category.isEmpty {
                    details.append(record.category)
                }
                if let processIdentifier = record.processIdentifier {
                    details.append("PID \(processIdentifier)")
                }
                if let sender = record.sender, !sender.isEmpty {
                    details.append(sender)
                }
                return details.isEmpty ? nil : details.joined(separator: " • ")
            case .full:
                var details = [record.category]
                if let process = record.process, !process.isEmpty {
                    details.append("process \(process)")
                }
                if let processIdentifier = record.processIdentifier {
                    details.append("pid \(processIdentifier)")
                }
                if let sender = record.sender, !sender.isEmpty {
                    details.append("sender \(sender)")
                }
                return details.joined(separator: " • ")
        }
    }

    private static func rowID(
        for record: BriteLogRecord,
        index: Int,
    ) -> String {
        let fingerprint = record.fingerprint
        return [
            String(index),
            String(fingerprint.date.timeIntervalSinceReferenceDate),
            fingerprint.subsystem,
            fingerprint.category,
            fingerprint.message,
            fingerprint.processIdentifier.map(String.init) ?? "nil",
        ].joined(separator: "::")
    }
}
