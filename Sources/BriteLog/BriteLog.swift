import Foundation
import ArgumentParser
import BriteLogCore
import BriteLogOSLogStore

@main
struct BriteLog: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "britelog",
        abstract: "Restyle and simplify unified log output while you debug macOS apps.",
        discussion: """
            BriteLog is a macOS-focused CLI for watching app logs and re-rendering them with terminal-friendly themes.
            The first live ingestion path reads Apple's unified logging system through OSLogStore and keeps the
            ingestion boundary separate from rendering so later sources can land in their own module.
            """,
        subcommands: [Watch.self]
    )
}

extension BriteLog {
    struct WatchPlan: Equatable, Sendable {
        var source: Source
        var subsystem: String?
        var category: String?
        var process: String?
        var processIdentifier: Int32?
        var theme: Theme
        var metadataMode: MetadataMode
        var persistHighlights: Bool
        var simplifyOutput: Bool
        var lookbackSeconds: TimeInterval
        var pollIntervalSeconds: Double
    }

    enum Source: String, CaseIterable, ExpressibleByArgument, Sendable {
        case oslogStore = "oslog-store"
    }

    enum Scope: String, CaseIterable, ExpressibleByArgument, Sendable {
        case currentProcess = "current-process"
        case localStore = "local-store"
    }

    enum Theme: String, CaseIterable, ExpressibleByArgument, Sendable {
        case xcode
        case neon
        case plain

        var coreTheme: BriteLogTheme {
            switch self {
            case .xcode:
                .xcode
            case .neon:
                .neon
            case .plain:
                .plain
            }
        }
    }

    enum MetadataMode: String, CaseIterable, ExpressibleByArgument, Sendable {
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
            abstract: "Tail live log entries through the first supported ingestion source."
        )

        @Option(help: "Choose where log entries come from.")
        var source: Source = .oslogStore

        @Option(help: "Choose which OSLogStore scope to open.")
        var scope: Scope = .currentProcess

        @Option(help: "Prefer log entries from this subsystem.")
        var subsystem: String?

        @Option(help: "Prefer log entries from this category.")
        var category: String?

        @Option(help: "Prefer log entries from this process name.")
        var process: String?

        @Option(name: [.customLong("process-id")], help: "Prefer log entries from this process identifier.")
        var processIdentifier: Int32?

        @Option(help: "Choose how re-rendered output should look in Terminal or Console.")
        var theme: Theme = .xcode

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

        func run() async throws {
            let plan = WatchPlan(
                source: source,
                subsystem: subsystem,
                category: category,
                process: process,
                processIdentifier: processIdentifier,
                theme: theme,
                metadataMode: metadata,
                persistHighlights: persistHighlights,
                simplifyOutput: simplifyOutput,
                lookbackSeconds: sinceSeconds,
                pollIntervalSeconds: pollInterval
            )

            let liveRequest = BriteLogLiveRequest(
                start: sinceSeconds > 0 ? .secondsBack(sinceSeconds) : .now,
                filter: BriteLogFilter(
                    subsystem: subsystem,
                    category: category,
                    process: process,
                    processIdentifier: processIdentifier
                ),
                pollInterval: .milliseconds(Int64((max(pollInterval, 0.1) * 1000).rounded()))
            )
            let renderer = BriteLogRenderer(
                theme: theme.coreTheme,
                metadataMode: metadata.coreMode
            )
            let source = makeLiveSource(for: source, scope: scope)

            printStartupBanner(for: plan, scope: scope)

            let stream = try source.liveEntries(matching: liveRequest)
            for try await record in stream {
                print(renderer.render(record))
            }
        }

        private func makeLiveSource(
            for source: Source,
            scope: Scope
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

        private func printStartupBanner(
            for plan: WatchPlan,
            scope: Scope
        ) {
            print(
                """
                BriteLog live watch started.
                  source: \(plan.source.rawValue)
                  scope: \(scope.rawValue)
                  subsystem: \(plan.subsystem ?? "any")
                  category: \(plan.category ?? "any")
                  process: \(plan.process ?? "any")
                  process id: \(plan.processIdentifier.map(String.init) ?? "any")
                  theme: \(plan.theme.rawValue)
                  metadata: \(plan.metadataMode.rawValue)
                  lookback: \(plan.lookbackSeconds)s
                  poll interval: \(plan.pollIntervalSeconds)s
                  simplify output: \(plan.simplifyOutput ? "yes" : "no")
                  persist highlights: \(plan.persistHighlights ? "yes" : "no")
                """
            )
        }
    }
}
