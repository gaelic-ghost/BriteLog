import BriteLogCore
import Foundation

struct BriteLogHighlightRule: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var matchText: String
    var subsystem: String
    var category: String
    var minimumLevel: BriteLogRecord.Level?
    var isEnabled: Bool

    var hasConstraints: Bool {
        !trimmedMatchText.isEmpty
            || !trimmedSubsystem.isEmpty
            || !trimmedCategory.isEmpty
            || minimumLevel != nil
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedMatchText: String {
        matchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSubsystem: String {
        subsystem.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedCategory: String {
        category.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var summary: String {
        var parts: [String] = []

        if !trimmedMatchText.isEmpty {
            parts.append("text “\(trimmedMatchText)”")
        }
        if !trimmedSubsystem.isEmpty {
            parts.append("subsystem \(trimmedSubsystem)")
        }
        if !trimmedCategory.isEmpty {
            parts.append("category \(trimmedCategory)")
        }
        if let minimumLevel {
            parts.append("level \(minimumLevel.rawValue.uppercased())+")
        }

        return parts.isEmpty ? "No constraints" : parts.joined(separator: " • ")
    }

    init(
        id: UUID = UUID(),
        name: String,
        matchText: String = "",
        subsystem: String = "",
        category: String = "",
        minimumLevel: BriteLogRecord.Level? = nil,
        isEnabled: Bool = true,
    ) {
        self.id = id
        self.name = name
        self.matchText = matchText
        self.subsystem = subsystem
        self.category = category
        self.minimumLevel = minimumLevel
        self.isEnabled = isEnabled
    }

    func matches(_ record: BriteLogRecord) -> Bool {
        guard isEnabled else {
            return false
        }
        guard hasConstraints else {
            return false
        }

        if let minimumLevel, record.level.rank < minimumLevel.rank {
            return false
        }
        if !trimmedSubsystem.isEmpty, record.subsystem != trimmedSubsystem {
            return false
        }
        if !trimmedCategory.isEmpty, record.category != trimmedCategory {
            return false
        }
        if !trimmedMatchText.isEmpty {
            let haystacks = [
                record.message,
                record.subsystem,
                record.category,
                record.process ?? "",
                record.sender ?? "",
            ]

            guard haystacks.contains(where: { $0.localizedCaseInsensitiveContains(trimmedMatchText) }) else {
                return false
            }
        }

        return true
    }
}
