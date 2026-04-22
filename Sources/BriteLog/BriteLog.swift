import ArgumentParser

@main
struct BriteLog: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "britelog",
        abstract: "Restyle and simplify unified log output while you debug macOS apps.",
        discussion: """
            BriteLog is a macOS-focused CLI for watching app logs and re-rendering them with terminal-friendly themes.
            This first scaffold keeps the package shape, command surface, and test baseline in place while the live
            OSLog and Xcode-facing integration is still ahead of us.
            """,
        subcommands: [Watch.self]
    )
}

extension BriteLog {
    struct WatchPlan: Equatable, Sendable {
        var subsystem: String?
        var category: String?
        var theme: Theme
        var metadataMode: MetadataMode
        var persistHighlights: Bool
        var simplifyOutput: Bool
    }

    enum Theme: String, CaseIterable, ExpressibleByArgument, Sendable {
        case xcode
        case neon
        case plain
    }

    enum MetadataMode: String, CaseIterable, ExpressibleByArgument, Sendable {
        case full
        case compact
        case hidden
    }

    struct Watch: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Prepare a live log-watching session for a target app."
        )

        @Option(help: "Prefer log entries from this subsystem.")
        var subsystem: String?

        @Option(help: "Prefer log entries from this category.")
        var category: String?

        @Option(help: "Choose how re-rendered output should look in Terminal or Console.")
        var theme: Theme = .xcode

        @Option(help: "Choose how much metadata to keep visible beside each message.")
        var metadata: MetadataMode = .compact

        @Flag(help: "Persist and re-highlight important matches across later output.")
        var persistHighlights = false

        @Flag(help: "Trim or simplify repetitive metadata where possible.")
        var simplifyOutput = false

        func run() async throws {
            let plan = WatchPlan(
                subsystem: subsystem,
                category: category,
                theme: theme,
                metadataMode: metadata,
                persistHighlights: persistHighlights,
                simplifyOutput: simplifyOutput
            )

            print(
                """
                BriteLog is bootstrapped and ready for implementation.
                Planned watch session:
                  subsystem: \(plan.subsystem ?? "any")
                  category: \(plan.category ?? "any")
                  theme: \(plan.theme.rawValue)
                  metadata: \(plan.metadataMode.rawValue)
                  persist highlights: \(plan.persistHighlights ? "yes" : "no")
                  simplify output: \(plan.simplifyOutput ? "yes" : "no")

                Live OSLog/Xcode capture is not implemented yet, but this command surface is now in place.
                """
            )
        }
    }
}
