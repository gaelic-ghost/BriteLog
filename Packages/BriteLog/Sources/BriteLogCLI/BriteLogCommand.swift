import ArgumentParser
import BriteLogCore
import BriteLogOSLogStore
import Foundation

public struct BriteLogCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "britelog",
        abstract: "Restyle and simplify unified log output while you debug macOS apps.",
        discussion: """
        BriteLog is a macOS-focused CLI for watching app logs and re-rendering them with terminal-friendly themes.
        The first live ingestion path reads Apple's unified logging system through OSLogStore and keeps the
        ingestion boundary separate from rendering so later sources can land in their own module.
        """,
        subcommands: [Watch.self, Themes.self, Doctor.self],
    )

    public init() {}
}

extension BriteLogCommand {
    struct WatchPlan: Equatable {
        var source: Source
        var allLogs: Bool
        var selfWatch: Bool
        var thisApp: Bool
        var bundleIdentifier: String?
        var subsystem: String?
        var category: String?
        var process: String?
        var processIdentifier: Int32?
        var sender: String?
        var messageContains: String?
        var minimumLevel: Level?
        var theme: Theme
        var metadataMode: MetadataMode
        var persistHighlights: Bool
        var simplifyOutput: Bool
        var lookbackSeconds: TimeInterval
        var pollIntervalSeconds: Double
    }

    enum Source: String, CaseIterable, ExpressibleByArgument {
        case oslogStore = "oslog-store"
    }

    enum Scope: String, CaseIterable, ExpressibleByArgument {
        case currentProcess = "current-process"
        case localStore = "local-store"
    }

    enum Level: String, CaseIterable, ExpressibleByArgument {
        case trace
        case debug
        case info
        case notice
        case warning
        case error
        case fault
        case critical

        var coreLevel: BriteLogRecord.Level {
            switch self {
                case .trace:
                    .trace
                case .debug:
                    .debug
                case .info:
                    .info
                case .notice:
                    .notice
                case .warning:
                    .warning
                case .error:
                    .error
                case .fault:
                    .fault
                case .critical:
                    .critical
            }
        }
    }

    enum Theme: String, CaseIterable, ExpressibleByArgument, Codable {
        case xcode
        case neon
        case aurora
        case ember
        case ice
        case plain

        var coreTheme: BriteLogTheme {
            switch self {
                case .xcode:
                    .xcode
                case .neon:
                    .neon
                case .aurora:
                    .aurora
                case .ember:
                    .ember
                case .ice:
                    .ice
                case .plain:
                    .plain
            }
        }
    }

    enum MetadataMode: String, CaseIterable, ExpressibleByArgument {
        case full
        case compact
        case hidden

        var coreMode: BriteLogMetadataMode {
            switch self {
                case .full:
                    .full
                case .compact:
                    .compact
                case .hidden:
                    .hidden
            }
        }
    }

    struct Watch: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Tail live log entries through the first supported ingestion source.",
        )

        static var introText: String {
            """
            BriteLog watches another app's unified logs and reprints them with developer-friendly formatting.

            Try one of these:
              swift run BriteLog watch --this-app
              swift run BriteLog watch --bundle-id com.example.MyApp
              swift run BriteLog watch --subsystem com.example.MyApp
              swift run BriteLog watch --process MyApp
              swift run BriteLog watch --all

            Notes:
              - Plain `watch` does not start the full machine-wide stream by default.
              - Use `--all` or `--console` if you really want the broader macOS log firehose.
              - Use `--self` only when you want to debug BriteLog itself.
            """
        }

        @Option(help: "Choose where log entries come from.")
        var source: Source = .oslogStore

        @Flag(name: [.customLong("all"), .customLong("console")], help: "Watch the broader macOS log stream without requiring a target filter.")
        var allLogs = false

        @Flag(name: [.customLong("self")], help: "Watch log entries emitted by the running BriteLog process itself.")
        var selfWatch = false

        @Flag(name: [.customLong("this-app")], help: "Resolve a bundle identifier from the current directory's single `.xcodeproj` and watch that app.")
        var thisApp = false

        @Option(name: [.customLong("bundle-id")], help: "Prefer log entries from this bundle identifier. This maps to subsystem filtering.")
        var bundleIdentifier: String?

        @Option(help: "Prefer log entries from this subsystem.")
        var subsystem: String?

        @Option(help: "Prefer log entries from this category.")
        var category: String?

        @Option(help: "Prefer log entries from this process name.")
        var process: String?

        @Option(name: [.customLong("process-id")], help: "Prefer log entries from this process identifier.")
        var processIdentifier: Int32?

        @Option(help: "Prefer log entries from this sender binary image name.")
        var sender: String?

        @Option(name: [.customLong("message-contains")], help: "Only keep entries whose composed message contains this text.")
        var messageContains: String?

        @Option(name: [.customLong("level-at-least")], help: "Only keep entries at or above this log level.")
        var minimumLevel: Level?

        @Option(help: "Choose how re-rendered output should look in Terminal or Console.")
        var theme: Theme?

        @Option(help: "Choose how much metadata to keep visible beside each message.")
        var metadata: MetadataMode = .compact

        @Option(name: [.customLong("since-seconds")], help: "Start by reading this many seconds of recent entries before continuing live.")
        var sinceSeconds: Double = 5

        @Option(name: [.customLong("poll-interval")], help: "Poll the store every N seconds for new entries.")
        var pollInterval: Double = 1

        @Flag(help: "Persist and re-highlight important matches across later output.")
        var persistHighlights = false

        @Flag(help: "Trim or simplify repetitive metadata where possible.")
        var simplifyOutput = false

        static func resolvedSubsystem(
            subsystem: String?,
            bundleIdentifier: String?,
        ) throws -> String? {
            switch (subsystem, bundleIdentifier) {
                case let (.some(subsystem), .some(bundleIdentifier)):
                    guard subsystem == bundleIdentifier else {
                        throw ValidationError(
                            """
                            `--bundle-id` maps to subsystem filtering, so it must match `--subsystem` when both are provided.
                            Received bundle id `\(bundleIdentifier)` and subsystem `\(subsystem)`.
                            """,
                        )
                    }

                    return subsystem
                case let (.some(subsystem), nil):
                    return subsystem
                case let (nil, .some(bundleIdentifier)):
                    return bundleIdentifier
                case (nil, nil):
                    return nil
            }
        }

        static func resolvedBundleIdentifier(
            bundleIdentifier: String?,
            thisApp: Bool,
            inferThisAppBundleIdentifier: () throws -> String = { try ThisAppBundleIdentifierResolver().resolve() },
        ) throws -> String? {
            guard thisApp else {
                return bundleIdentifier
            }

            let inferred = try inferThisAppBundleIdentifier()
            guard let bundleIdentifier else {
                return inferred
            }
            guard bundleIdentifier == inferred else {
                throw ValidationError(
                    """
                    `--this-app` resolved bundle id `\(inferred)`, which does not match the explicit `--bundle-id`
                    value `\(bundleIdentifier)`.
                    """,
                )
            }

            return bundleIdentifier
        }

        static func resolvedScope(selfWatch: Bool) -> Scope {
            selfWatch ? .currentProcess : .localStore
        }

        static func resolvedTheme(
            theme: Theme?,
            loadConfiguration: () throws -> BriteLogConfiguration = { try BriteLogConfigurationStore().load() },
        ) throws -> Theme {
            if let theme {
                return theme
            }
            return try loadConfiguration().selectedTheme ?? .xcode
        }

        static func shouldStartWatching(
            allLogs: Bool,
            selfWatch: Bool,
            filter: BriteLogFilter,
        ) -> Bool {
            allLogs || selfWatch || filter.hasFocusConstraint
        }

        static func startupBanner(
            for plan: WatchPlan,
            scope: Scope,
        ) -> String {
            """
            BriteLog live watch started.
              source: \(plan.source.rawValue)
              all logs: \(plan.allLogs ? "yes" : "no")
              self: \(plan.selfWatch ? "yes" : "no")
              scope: \(scope.rawValue)
              this app: \(plan.thisApp ? "yes" : "no")
              bundle id: \(plan.bundleIdentifier ?? "any")
              subsystem: \(plan.subsystem ?? "any")
              category: \(plan.category ?? "any")
              process: \(plan.process ?? "any")
              process id: \(plan.processIdentifier.map(String.init) ?? "any")
              sender: \(plan.sender ?? "any")
              message contains: \(plan.messageContains ?? "any")
              minimum level: \(plan.minimumLevel?.rawValue ?? "any")
              theme: \(plan.theme.rawValue)
              metadata: \(plan.metadataMode.rawValue)
              lookback: \(plan.lookbackSeconds)s
              poll interval: \(plan.pollIntervalSeconds)s
              simplify output: \(plan.simplifyOutput ? "yes" : "no")
              persist highlights: \(plan.persistHighlights ? "yes" : "no")
            """
        }

        static func scopeNote(
            for filter: BriteLogFilter,
            scope: Scope,
        ) -> String? {
            guard scope == .localStore, !filter.hasFocusConstraint else {
                return nil
            }

            return """
            Note: `local-store` with no focus filters will watch the broader macOS log stream.
            Add `--subsystem`, `--process`, `--process-id`, `--sender`, or `--message-contains` to narrow the watch to a target app.
            """
        }

        func run() async throws {
            let resolvedBundleIdentifier = try Self.resolvedBundleIdentifier(
                bundleIdentifier: bundleIdentifier,
                thisApp: thisApp,
            )
            let resolvedSubsystem = try Self.resolvedSubsystem(
                subsystem: subsystem,
                bundleIdentifier: resolvedBundleIdentifier,
            )
            let resolvedScope = Self.resolvedScope(selfWatch: selfWatch)
            let resolvedTheme = try Self.resolvedTheme(theme: theme)
            let plan = WatchPlan(
                source: source,
                allLogs: allLogs,
                selfWatch: selfWatch,
                thisApp: thisApp,
                bundleIdentifier: resolvedBundleIdentifier,
                subsystem: resolvedSubsystem,
                category: category,
                process: process,
                processIdentifier: processIdentifier,
                sender: sender,
                messageContains: messageContains,
                minimumLevel: minimumLevel,
                theme: resolvedTheme,
                metadataMode: metadata,
                persistHighlights: persistHighlights,
                simplifyOutput: simplifyOutput,
                lookbackSeconds: sinceSeconds,
                pollIntervalSeconds: pollInterval,
            )

            let liveRequest = BriteLogLiveRequest(
                start: sinceSeconds > 0 ? .secondsBack(sinceSeconds) : .now,
                filter: BriteLogFilter(
                    subsystem: resolvedSubsystem,
                    category: category,
                    process: process,
                    processIdentifier: processIdentifier,
                    sender: sender,
                    messageContains: messageContains,
                    minimumLevel: minimumLevel?.coreLevel,
                ),
                pollInterval: .milliseconds(Int64((max(pollInterval, 0.1) * 1000).rounded())),
            )
            let renderer = BriteLogRenderer(
                theme: resolvedTheme.coreTheme,
                metadataMode: metadata.coreMode,
            )
            let source = makeLiveSource(for: source, scope: resolvedScope)

            guard Self.shouldStartWatching(
                allLogs: allLogs,
                selfWatch: selfWatch,
                filter: liveRequest.filter,
            ) else {
                print(Self.introText)
                return
            }

            print(Self.startupBanner(for: plan, scope: resolvedScope))
            if let scopeNote = Self.scopeNote(for: liveRequest.filter, scope: resolvedScope) {
                print(scopeNote)
            }

            do {
                let stream = try source.liveEntries(matching: liveRequest)
                for try await record in stream {
                    print(renderer.render(record))
                }
            } catch {
                throw CleanExit.message(
                    """
                    \(error.localizedDescription)

                    Tip: run `britelog doctor` to see which OSLogStore scopes are available in this build and environment.
                    """,
                )
            }
        }

        private func makeLiveSource(
            for source: Source,
            scope: Scope,
        ) -> some BriteLogLiveSource {
            switch source {
                case .oslogStore:
                    BriteLogOSLogStoreSource(scope: coreScope(from: scope))
            }
        }

        private func coreScope(from scope: Scope) -> BriteLogOSLogStoreScope {
            switch scope {
                case .currentProcess:
                    .currentProcess
                case .localStore:
                    .localStore
            }
        }
    }

    struct Themes: ParsableCommand {
        struct List: ParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "list",
                abstract: "List available color themes and show the saved default.",
            )

            static func output(
                configuration: BriteLogConfiguration,
            ) -> String {
                let selected = configuration.selectedTheme ?? .xcode
                var lines = ["BriteLog themes"]

                for theme in Theme.allCases {
                    let marker = theme == selected ? "*" : " "
                    let suffix = theme == selected ? " (current default)" : ""
                    lines.append("\(marker) \(theme.rawValue) - \(theme.displayName)\(suffix)")
                    lines.append("  \(theme.summary)")
                }

                lines.append("")
                lines.append("Use `swift run BriteLog themes select <theme>` to change the saved default.")
                return lines.joined(separator: "\n")
            }

            mutating func run() throws {
                let store = BriteLogConfigurationStore()
                let configuration = try store.load()
                print(Self.output(configuration: configuration))
            }
        }

        struct Select: ParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "select",
                abstract: "Save a default theme for later BriteLog runs.",
            )

            @Argument(help: "The theme to save as the default.")
            var theme: Theme

            mutating func run() throws {
                let store = BriteLogConfigurationStore()
                var configuration = try store.load()
                configuration.selectedTheme = theme
                try store.save(configuration)

                print(
                    """
                    Saved BriteLog default theme: \(theme.rawValue)
                    \(theme.summary)
                    """,
                )
            }
        }

        static let configuration = CommandConfiguration(
            commandName: "themes",
            abstract: "List available color themes and manage the saved default.",
            subcommands: [List.self, Select.self],
        )

        mutating func run() throws {
            var command = List()
            try command.run()
        }
    }

    struct Doctor: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Report which OSLogStore access paths are available in the current environment.",
        )

        static func output(
            capabilities: [BriteLogOSLogStoreSource.Capability],
        ) -> String {
            var lines = ["BriteLog doctor"]

            for capability in capabilities {
                let status = capability.available ? "available" : "unavailable"
                lines.append("  \(capability.scope.rawValue): \(status)")
                lines.append("    \(capability.summary)")
                if let detail = capability.detail {
                    lines.append("    \(detail)")
                }
            }

            lines.append("")
            lines.append("Notes:")
            lines.append("  - `current-process` is the narrow safe path and only sees logs emitted by the running BriteLog process.")
            lines.append("  - `local-store` is the broader macOS path for cross-process reading, but Apple documents that it requires system permission and the `com.apple.logging.local-store` entitlement.")
            lines.append("  - If `local-store` is unavailable here, a simple signed wrapper app may still not be enough on its own; the real distribution story depends on whether this build can carry the needed entitlement.")
            return lines.joined(separator: "\n")
        }

        mutating func run() throws {
            print(Self.output(capabilities: BriteLogOSLogStoreSource.capabilityReport()))
        }
    }
}
