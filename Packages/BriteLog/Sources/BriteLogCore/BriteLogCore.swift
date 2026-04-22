import Foundation

public struct BriteLogRecord: Equatable, Sendable {
    public enum Level: String, Equatable, Sendable {
        case trace
        case debug
        case info
        case notice
        case warning
        case error
        case fault
        case critical
        case undefined

        public var rank: Int {
            switch self {
                case .trace:
                    0
                case .debug:
                    1
                case .info:
                    2
                case .notice:
                    3
                case .warning:
                    4
                case .error:
                    5
                case .fault:
                    6
                case .critical:
                    7
                case .undefined:
                    -1
            }
        }
    }

    public struct Fingerprint: Hashable, Sendable {
        public var date: Date
        public var processIdentifier: Int32?
        public var subsystem: String
        public var category: String
        public var message: String

        public init(
            date: Date,
            processIdentifier: Int32?,
            subsystem: String,
            category: String,
            message: String,
        ) {
            self.date = date
            self.processIdentifier = processIdentifier
            self.subsystem = subsystem
            self.category = category
            self.message = message
        }
    }

    public var date: Date
    public var level: Level
    public var subsystem: String
    public var category: String
    public var process: String?
    public var processIdentifier: Int32?
    public var sender: String?
    public var message: String

    public var fingerprint: Fingerprint {
        Fingerprint(
            date: date,
            processIdentifier: processIdentifier,
            subsystem: subsystem,
            category: category,
            message: message,
        )
    }

    public init(
        date: Date,
        level: Level,
        subsystem: String,
        category: String,
        process: String?,
        processIdentifier: Int32?,
        sender: String?,
        message: String,
    ) {
        self.date = date
        self.level = level
        self.subsystem = subsystem
        self.category = category
        self.process = process
        self.processIdentifier = processIdentifier
        self.sender = sender
        self.message = message
    }
}

public struct BriteLogFilter: Equatable, Sendable {
    public var subsystem: String?
    public var category: String?
    public var process: String?
    public var processIdentifier: Int32?
    public var sender: String?
    public var messageContains: String?
    public var minimumLevel: BriteLogRecord.Level?

    public var hasFocusConstraint: Bool {
        subsystem != nil
            || category != nil
            || process != nil
            || processIdentifier != nil
            || sender != nil
            || messageContains != nil
    }

    public init(
        subsystem: String? = nil,
        category: String? = nil,
        process: String? = nil,
        processIdentifier: Int32? = nil,
        sender: String? = nil,
        messageContains: String? = nil,
        minimumLevel: BriteLogRecord.Level? = nil,
    ) {
        self.subsystem = subsystem
        self.category = category
        self.process = process
        self.processIdentifier = processIdentifier
        self.sender = sender
        self.messageContains = messageContains
        self.minimumLevel = minimumLevel
    }

    public func matches(_ record: BriteLogRecord) -> Bool {
        if let subsystem, record.subsystem != subsystem {
            return false
        }
        if let category, record.category != category {
            return false
        }
        if let process, record.process != process {
            return false
        }
        if let processIdentifier, record.processIdentifier != processIdentifier {
            return false
        }
        if let sender, record.sender != sender {
            return false
        }
        if let messageContains {
            let haystack = record.message.localizedCaseInsensitiveContains(messageContains)
            if !haystack {
                return false
            }
        }
        if let minimumLevel, record.level.rank < minimumLevel.rank {
            return false
        }
        return true
    }
}

public struct BriteLogLiveRequest: Equatable, Sendable {
    public enum Start: Equatable, Sendable {
        case now
        case secondsBack(TimeInterval)
        case date(Date)
    }

    public var start: Start
    public var filter: BriteLogFilter
    public var pollInterval: Duration

    public init(
        start: Start,
        filter: BriteLogFilter = .init(),
        pollInterval: Duration = .seconds(1),
    ) {
        self.start = start
        self.filter = filter
        self.pollInterval = pollInterval
    }
}

public enum BriteLogTheme: String, CaseIterable, Sendable {
    case xcode
    case neon
    case aurora
    case ember
    case ice
    case plain
}

public enum BriteLogMetadataMode: String, CaseIterable, Sendable {
    case full
    case compact
    case hidden
}

public protocol BriteLogLiveSource: Sendable {
    func liveEntries(
        matching request: BriteLogLiveRequest,
    ) throws -> AsyncThrowingStream<BriteLogRecord, Error>
}

public struct BriteLogRenderer: Sendable {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    public var theme: BriteLogTheme
    public var metadataMode: BriteLogMetadataMode

    public init(
        theme: BriteLogTheme,
        metadataMode: BriteLogMetadataMode,
    ) {
        self.theme = theme
        self.metadataMode = metadataMode
    }

    public func render(_ record: BriteLogRecord) -> String {
        let timestamp = Self.dateFormatter.string(from: record.date)
        let level = colorize(record.level.rawValue.uppercased(), for: record.level)
        let metadata = renderMetadata(for: record)
        let message = colorize(record.message, for: record.level, isMessage: true)

        if metadata.isEmpty {
            return "\(timestamp) \(level) \(message)"
        }
        return "\(timestamp) \(level) \(metadata) \(message)"
    }

    private func renderMetadata(for record: BriteLogRecord) -> String {
        switch metadataMode {
            case .hidden:
                return ""
            case .compact:
                let process = record.process ?? "unknown-process"
                let subsystem = record.subsystem.isEmpty ? "-" : record.subsystem
                let category = record.category.isEmpty ? "-" : record.category
                if let sender = record.sender, !sender.isEmpty, sender != process {
                    return "[\(process) \(sender) \(subsystem):\(category)]"
                }
                return "[\(process) \(subsystem):\(category)]"
            case .full:
                let process = record.process ?? "unknown-process"
                let pid = record.processIdentifier.map(String.init) ?? "?"
                let sender = record.sender ?? "-"
                let subsystem = record.subsystem.isEmpty ? "-" : record.subsystem
                let category = record.category.isEmpty ? "-" : record.category
                return "[process=\(process) pid=\(pid) sender=\(sender) subsystem=\(subsystem) category=\(category)]"
        }
    }

    private func colorize(
        _ text: String,
        for level: BriteLogRecord.Level,
        isMessage: Bool = false,
    ) -> String {
        guard theme != .plain else {
            return text
        }

        let code = switch (theme, level, isMessage) {
            case (.xcode, .trace, false): "38;5;245"
            case (.xcode, .debug, false): "36"
            case (.xcode, .info, false): "32"
            case (.xcode, .notice, false): "34"
            case (.xcode, .warning, false): "33"
            case (.xcode, .error, false): "31"
            case (.xcode, .fault, false): "35"
            case (.xcode, .critical, false): "1;31"
            case (.xcode, .undefined, false): "37"
            case (.neon, .trace, false): "38;5;147"
            case (.neon, .debug, false): "38;5;51"
            case (.neon, .info, false): "38;5;121"
            case (.neon, .notice, false): "38;5;45"
            case (.neon, .warning, false): "38;5;227"
            case (.neon, .error, false): "38;5;197"
            case (.neon, .fault, false): "38;5;201"
            case (.neon, .critical, false): "1;38;5;199"
            case (.neon, .undefined, false): "38;5;255"
            case (.aurora, .trace, false): "38;5;110"
            case (.aurora, .debug, false): "38;5;80"
            case (.aurora, .info, false): "38;5;121"
            case (.aurora, .notice, false): "38;5;159"
            case (.aurora, .warning, false): "38;5;222"
            case (.aurora, .error, false): "38;5;210"
            case (.aurora, .fault, false): "38;5;177"
            case (.aurora, .critical, false): "1;38;5;204"
            case (.aurora, .undefined, false): "38;5;188"
            case (.ember, .trace, false): "38;5;240"
            case (.ember, .debug, false): "38;5;179"
            case (.ember, .info, false): "38;5;150"
            case (.ember, .notice, false): "38;5;215"
            case (.ember, .warning, false): "38;5;220"
            case (.ember, .error, false): "38;5;203"
            case (.ember, .fault, false): "38;5;199"
            case (.ember, .critical, false): "1;38;5;196"
            case (.ember, .undefined, false): "38;5;252"
            case (.ice, .trace, false): "38;5;153"
            case (.ice, .debug, false): "38;5;117"
            case (.ice, .info, false): "38;5;87"
            case (.ice, .notice, false): "38;5;81"
            case (.ice, .warning, false): "38;5;229"
            case (.ice, .error, false): "38;5;211"
            case (.ice, .fault, false): "38;5;141"
            case (.ice, .critical, false): "1;38;5;197"
            case (.ice, .undefined, false): "38;5;255"
            case (_, .warning, true): "33"
            case (_, .error, true): "31"
            case (_, .fault, true): "35"
            case (_, .critical, true): "1;31"
            default: "0"
        }

        return "\u{001B}[\(code)m\(text)\u{001B}[0m"
    }
}
