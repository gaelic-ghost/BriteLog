import ArgumentParser
@testable import BriteLogCLI
@testable import BriteLogCore
@testable import BriteLogOSLogStore
import Foundation
import Testing

private func expectSnapshot(
    _ actual: String,
    matches expected: String,
) {
    #expect(actual == expected)
}

@Test func `watch plan carries chosen presentation defaults`() {
    let plan = BriteLogCommand.WatchPlan(
        source: .oslogStore,
        allLogs: false,
        selfWatch: false,
        thisApp: false,
        bundleIdentifier: "com.gaelic-ghost.demo",
        subsystem: "com.gaelic-ghost.demo",
        category: "rendering",
        process: "DemoApp",
        processIdentifier: 42,
        sender: "DemoApp",
        messageContains: "warning",
        minimumLevel: .notice,
        theme: .xcode,
        metadataMode: .compact,
        persistHighlights: true,
        simplifyOutput: true,
        lookbackSeconds: 5,
        pollIntervalSeconds: 1,
    )

    #expect(plan.source == .oslogStore)
    #expect(!plan.allLogs)
    #expect(!plan.selfWatch)
    #expect(!plan.thisApp)
    #expect(plan.bundleIdentifier == "com.gaelic-ghost.demo")
    #expect(plan.subsystem == "com.gaelic-ghost.demo")
    #expect(plan.category == "rendering")
    #expect(plan.process == "DemoApp")
    #expect(plan.processIdentifier == 42)
    #expect(plan.sender == "DemoApp")
    #expect(plan.messageContains == "warning")
    #expect(plan.minimumLevel == .notice)
    #expect(plan.theme == .xcode)
    #expect(plan.metadataMode == .compact)
    #expect(plan.persistHighlights)
    #expect(plan.simplifyOutput)
    #expect(plan.lookbackSeconds == 5)
    #expect(plan.pollIntervalSeconds == 1)
}

@Test func `theme list stays stable for cli parsing`() {
    #expect(BriteLogCommand.Theme.allCases.map(\.rawValue) == ["xcode", "neon", "aurora", "ember", "ice", "plain"])
    #expect(BriteLogCommand.MetadataMode.allCases.map(\.rawValue) == ["full", "compact", "hidden"])
    #expect(BriteLogCommand.Level.allCases.map(\.rawValue) == ["trace", "debug", "info", "notice", "warning", "error", "fault", "critical"])
    #expect(BriteLogCommand.Source.allCases.map(\.rawValue) == ["oslog-store"])
    #expect(BriteLogCommand.Scope.allCases.map(\.rawValue) == ["current-process", "local-store"])
}

@Test func `watch intro text snapshot stays stable`() {
    expectSnapshot(
        BriteLogCommand.Watch.introText,
        matches: """
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
        """,
    )
}

@Test func `themes list output snapshot stays stable`() {
    expectSnapshot(
        BriteLogCommand.Themes.List.output(configuration: .init(selectedTheme: .ember)),
        matches: """
        BriteLog themes
          xcode - Xcode
          Balanced IDE-style colors for everyday debugging.
          neon - Neon
          Higher-contrast terminal colors with a brighter cyber look.
          aurora - Aurora
          Cool teal and pink highlights with a softer night-sky palette.
        * ember - Ember (current default)
          Warm amber and ember tones for a hotter, warning-forward terminal look.
          ice - Ice
          Frosty cyan and pale-blue accents with crisp cool contrast.
          plain - Plain
          No ANSI colors, just readable structured text.

        Use `swift run BriteLog themes select <theme>` to change the saved default.
        """,
    )
}

@Test func `doctor output snapshot stays stable`() {
    let capabilities: [BriteLogOSLogStoreSource.Capability] = [
        .init(
            scope: .currentProcess,
            available: true,
            summary: "Current-process OSLogStore access is available.",
            detail: "This scope only reads unified log entries emitted by the current BriteLog process.",
        ),
        .init(
            scope: .localStore,
            available: false,
            summary: "Local-store OSLogStore access is unavailable.",
            detail: "Denied for test coverage.",
        ),
    ]

    expectSnapshot(
        BriteLogCommand.Doctor.output(capabilities: capabilities),
        matches: """
        BriteLog doctor
          current-process: available
            Current-process OSLogStore access is available.
            This scope only reads unified log entries emitted by the current BriteLog process.
          local-store: unavailable
            Local-store OSLogStore access is unavailable.
            Denied for test coverage.

        Notes:
          - `current-process` is the narrow safe path and only sees logs emitted by the running BriteLog process.
          - `local-store` is the broader macOS path for cross-process reading, but Apple documents that it requires system permission and the `com.apple.logging.local-store` entitlement.
          - If `local-store` is unavailable here, a simple signed wrapper app may still not be enough on its own; the real distribution story depends on whether this build can carry the needed entitlement.
        """,
    )
}

@Test func `watch uses saved theme when no explicit theme is provided`() throws {
    let resolved = try BriteLogCommand.Watch.resolvedTheme(
        theme: nil,
        loadConfiguration: { .init(selectedTheme: .neon) },
    )

    #expect(resolved == .neon)
}

@Test func `explicit theme overrides saved theme`() throws {
    let resolved = try BriteLogCommand.Watch.resolvedTheme(
        theme: .plain,
        loadConfiguration: { .init(selectedTheme: .neon) },
    )

    #expect(resolved == .plain)
}

@Test func `configuration store round trips selected theme`() throws {
    let temporaryDirectory = FileManager.default
        .temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let configURL = temporaryDirectory.appendingPathComponent("config.json")
    let legacyConfigURL = temporaryDirectory.appendingPathComponent("legacy.json")
    let store = BriteLogConfigurationStore(configURL: configURL, legacyConfigURL: legacyConfigURL)

    try store.save(BriteLogConfiguration(selectedTheme: .neon))
    let loaded = try store.load()

    #expect(loaded.selectedTheme == BriteLogCommand.Theme.neon)
}

@Test func `configuration store falls back to the legacy config location`() throws {
    let temporaryDirectory = FileManager.default
        .temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let configURL = temporaryDirectory.appendingPathComponent("config.json")
    let legacyConfigURL = temporaryDirectory.appendingPathComponent("legacy.json")
    let store = BriteLogConfigurationStore(configURL: configURL, legacyConfigURL: legacyConfigURL)

    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    try JSONEncoder.pretty
        .encode(BriteLogConfiguration(selectedTheme: .plain))
        .write(to: legacyConfigURL, options: .atomic)

    let loaded = try store.load()

    #expect(loaded.selectedTheme == .plain)
}

@Test func `self watch resolves current process scope`() {
    #expect(BriteLogCommand.Watch.resolvedScope(selfWatch: false) == .localStore)
    #expect(BriteLogCommand.Watch.resolvedScope(selfWatch: true) == .currentProcess)
}

@Test func `watch start requires explicit focus or all logs`() {
    #expect(!BriteLogCommand.Watch.shouldStartWatching(
        allLogs: false,
        selfWatch: false,
        filter: .init(),
    ))
    #expect(BriteLogCommand.Watch.shouldStartWatching(
        allLogs: true,
        selfWatch: false,
        filter: .init(),
    ))
    #expect(BriteLogCommand.Watch.shouldStartWatching(
        allLogs: false,
        selfWatch: true,
        filter: .init(),
    ))
    #expect(BriteLogCommand.Watch.shouldStartWatching(
        allLogs: false,
        selfWatch: false,
        filter: .init(subsystem: "com.gaelic-ghost.demo"),
    ))
}

@Test func `bundle identifier resolves to subsystem filter`() throws {
    #expect(try BriteLogCommand.Watch.resolvedSubsystem(subsystem: nil, bundleIdentifier: "com.gaelic-ghost.demo") == "com.gaelic-ghost.demo")
    #expect(try BriteLogCommand.Watch.resolvedSubsystem(subsystem: "com.gaelic-ghost.demo", bundleIdentifier: nil) == "com.gaelic-ghost.demo")
    #expect(try BriteLogCommand.Watch.resolvedSubsystem(subsystem: "com.gaelic-ghost.demo", bundleIdentifier: "com.gaelic-ghost.demo") == "com.gaelic-ghost.demo")
}

@Test func `this app scheme selection prefers project name`() throws {
    #expect(try ThisAppBundleIdentifierResolver.chooseScheme(
        schemes: ["DemoApp", "DemoLibrary"],
        projectName: "DemoApp",
    ) == "DemoApp")
}

@Test func `this app build settings prefer matching app target`() throws {
    let entries = [
        ThisAppBundleIdentifierResolver.BuildSettingsEntry(
            target: "DemoApp",
            buildSettings: [
                "PRODUCT_BUNDLE_IDENTIFIER": "com.gaelic-ghost.demo",
                "WRAPPER_EXTENSION": "app",
            ],
        ),
        ThisAppBundleIdentifierResolver.BuildSettingsEntry(
            target: "DemoFramework",
            buildSettings: [
                "PRODUCT_BUNDLE_IDENTIFIER": "com.gaelic-ghost.framework",
                "WRAPPER_EXTENSION": "framework",
            ],
        ),
    ]

    #expect(try ThisAppBundleIdentifierResolver.chooseBundleIdentifier(
        entries: entries,
        preferredName: "DemoApp",
        projectName: "DemoApp",
    ) == "com.gaelic-ghost.demo")
}

@Test func `explicit bundle identifier must match this app inference`() throws {
    do {
        _ = try BriteLogCommand.Watch.resolvedBundleIdentifier(
            bundleIdentifier: "com.gaelic-ghost.one",
            thisApp: true,
            inferThisAppBundleIdentifier: { "com.gaelic-ghost.two" },
        )
        Issue.record("Expected `--this-app` inference mismatch to throw a validation error.")
    } catch {
        #expect("\(error)".contains("--this-app"))
    }
}

@Test func `conflicting bundle identifier and subsystem are rejected`() throws {
    #expect(throws: ValidationError.self) {
        _ = try BriteLogCommand.Watch.resolvedSubsystem(
            subsystem: "com.gaelic-ghost.one",
            bundleIdentifier: "com.gaelic-ghost.two",
        )
    }
}

@Test func `filter matches only requested fields`() {
    let record = BriteLogRecord(
        date: .init(timeIntervalSince1970: 100),
        level: .notice,
        subsystem: "com.gaelic-ghost.demo",
        category: "rendering",
        process: "DemoApp",
        processIdentifier: 7,
        sender: "DemoApp",
        message: "Rendered line",
    )

    #expect(BriteLogFilter(subsystem: "com.gaelic-ghost.demo").matches(record))
    #expect(BriteLogFilter(category: "rendering").matches(record))
    #expect(BriteLogFilter(process: "DemoApp").matches(record))
    #expect(BriteLogFilter(processIdentifier: 7).matches(record))
    #expect(BriteLogFilter(sender: "DemoApp").matches(record))
    #expect(BriteLogFilter(messageContains: "rendered").matches(record))
    #expect(BriteLogFilter(minimumLevel: .notice).matches(record))
    #expect(!BriteLogFilter(messageContains: "fault").matches(record))
    #expect(!BriteLogFilter(minimumLevel: .error).matches(record))
    #expect(!BriteLogFilter(subsystem: "other").matches(record))
    #expect(!BriteLogFilter(processIdentifier: 99).matches(record))
}

@Test func `renderer keeps plain theme readable`() {
    let renderer = BriteLogRenderer(theme: .plain, metadataMode: .compact)
    let rendered = renderer.render(
        BriteLogRecord(
            date: .init(timeIntervalSince1970: 100),
            level: .warning,
            subsystem: "com.gaelic-ghost.demo",
            category: "rendering",
            process: "DemoApp",
            processIdentifier: 7,
            sender: "DemoApp Helper",
            message: "Watch this line",
        ),
    )

    #expect(rendered.contains("WARNING"))
    #expect(rendered.contains("[DemoApp DemoApp Helper com.gaelic-ghost.demo:rendering]"))
    #expect(rendered.contains("Watch this line"))
    #expect(!rendered.contains("\u{001B}["))
}

@Test(arguments: [
    (BriteLogTheme.xcode, Optional("33"), Optional("31")),
    (.neon, Optional("38;5;227"), Optional("31")),
    (.aurora, Optional("38;5;222"), Optional("31")),
    (.ember, Optional("38;5;220"), Optional("31")),
    (.ice, Optional("38;5;229"), Optional("31")),
    (.plain, String?.none, String?.none),
])
func `renderer ansi color codes stay stable`(
    theme: BriteLogTheme,
    warningLabelCode: String?,
    errorMessageCode: String?,
) {
    let renderer = BriteLogRenderer(theme: theme, metadataMode: .compact)

    #expect(renderer.ansiCode(for: .warning) == warningLabelCode)
    #expect(renderer.ansiCode(for: .error, isMessage: true) == errorMessageCode)
}

@Test(arguments: [BriteLogTheme.xcode, .neon, .aurora, .ember, .ice])
func `renderer emits ansi sequences for colored themes`(theme: BriteLogTheme) {
    let renderer = BriteLogRenderer(theme: theme, metadataMode: .compact)
    let rendered = renderer.render(
        BriteLogRecord(
            date: .init(timeIntervalSince1970: 100),
            level: .error,
            subsystem: "com.gaelic-ghost.demo",
            category: "rendering",
            process: "DemoApp",
            processIdentifier: 7,
            sender: nil,
            message: "Watch this line",
        ),
    )

    #expect(rendered.contains("\u{001B}["))
    #expect(rendered.contains("Watch this line"))
}

@Test func `watch startup banner snapshot stays stable`() {
    let plan = BriteLogCommand.WatchPlan(
        source: .oslogStore,
        allLogs: true,
        selfWatch: false,
        thisApp: true,
        bundleIdentifier: "com.gaelic-ghost.demo",
        subsystem: "com.gaelic-ghost.demo",
        category: "rendering",
        process: "DemoApp",
        processIdentifier: 42,
        sender: "DemoApp",
        messageContains: "fatal",
        minimumLevel: .error,
        theme: .aurora,
        metadataMode: .full,
        persistHighlights: true,
        simplifyOutput: true,
        lookbackSeconds: 3,
        pollIntervalSeconds: 0.5,
    )

    expectSnapshot(
        BriteLogCommand.Watch.startupBanner(for: plan, scope: .localStore),
        matches: """
        BriteLog live watch started.
          source: oslog-store
          all logs: yes
          self: no
          scope: local-store
          this app: yes
          bundle id: com.gaelic-ghost.demo
          subsystem: com.gaelic-ghost.demo
          category: rendering
          process: DemoApp
          process id: 42
          sender: DemoApp
          message contains: fatal
          minimum level: error
          theme: aurora
          metadata: full
          lookback: 3.0s
          poll interval: 0.5s
          simplify output: yes
          persist highlights: yes
        """,
    )
}

@Test func `watch scope note only appears for unfocused local store watches`() {
    #expect(
        BriteLogCommand.Watch.scopeNote(
            for: .init(),
            scope: .localStore,
        ) == """
        Note: `local-store` with no focus filters will watch the broader macOS log stream.
        Add `--subsystem`, `--process`, `--process-id`, `--sender`, or `--message-contains` to narrow the watch to a target app.
        """,
    )
    #expect(BriteLogCommand.Watch.scopeNote(
        for: .init(subsystem: "com.gaelic-ghost.demo"),
        scope: .localStore,
    ) == nil)
    #expect(BriteLogCommand.Watch.scopeNote(
        for: .init(),
        scope: .currentProcess,
    ) == nil)
}

@Test func `focus constraint reflects cross process targeting`() {
    #expect(!BriteLogFilter().hasFocusConstraint)
    #expect(BriteLogFilter(subsystem: "com.gaelic-ghost.demo").hasFocusConstraint)
    #expect(BriteLogFilter(sender: "DemoApp").hasFocusConstraint)
    #expect(BriteLogFilter(messageContains: "fatal").hasFocusConstraint)
}

@Test func `oslog cursor deduplicates trailing entries and advances from the latest record date`() async throws {
    final class BatchSource: @unchecked Sendable {
        var batches: [[BriteLogOSLogStoreSource.StoreRecord]]
        var requestedDates: [Date] = []
        var index = 0

        init(batches: [[BriteLogOSLogStoreSource.StoreRecord]]) {
            self.batches = batches
        }

        func fetch(date: Date) -> [BriteLogOSLogStoreSource.StoreRecord] {
            requestedDates.append(date)
            defer { index += 1 }
            return batches[index]
        }
    }

    let startDate = Date(timeIntervalSince1970: 100)
    let source = BatchSource(
        batches: [
            [
                .init(
                    date: startDate,
                    level: .notice,
                    subsystem: "com.gaelic-ghost.demo",
                    category: "rendering",
                    process: "DemoApp",
                    processIdentifier: 7,
                    sender: "DemoApp",
                    message: " repeated ",
                ),
                .init(
                    date: startDate,
                    level: .notice,
                    subsystem: "com.gaelic-ghost.demo",
                    category: "rendering",
                    process: "DemoApp",
                    processIdentifier: 7,
                    sender: "DemoApp",
                    message: " repeated ",
                ),
                .init(
                    date: startDate.addingTimeInterval(1),
                    level: .warning,
                    subsystem: "com.gaelic-ghost.demo",
                    category: "rendering",
                    process: "DemoApp",
                    processIdentifier: 8,
                    sender: "DemoApp Helper",
                    message: "   ",
                ),
            ],
            [
                .init(
                    date: startDate.addingTimeInterval(1),
                    level: .warning,
                    subsystem: "com.gaelic-ghost.demo",
                    category: "rendering",
                    process: "DemoApp",
                    processIdentifier: 8,
                    sender: "DemoApp Helper",
                    message: "   ",
                ),
                .init(
                    date: startDate.addingTimeInterval(2),
                    level: .error,
                    subsystem: "com.gaelic-ghost.demo",
                    category: "rendering",
                    process: "DemoApp",
                    processIdentifier: 7,
                    sender: "DemoApp",
                    message: "new failure",
                ),
            ],
        ],
    )
    let cursor = BriteLogOSLogCursor(
        fetchRecords: { date in source.fetch(date: date) },
        startDate: startDate,
        filter: .init(),
    )

    let firstBatch = try await cursor.nextBatch()
    let secondBatch = try await cursor.nextBatch()

    #expect(firstBatch.count == 2)
    #expect(firstBatch.map(\.message) == ["repeated", "<empty log message>"])
    #expect(secondBatch.count == 1)
    #expect(secondBatch.map(\.message) == ["new failure"])
    #expect(source.requestedDates == [startDate, startDate.addingTimeInterval(1)])
}

@Test func `oslog cursor applies filters before yielding records`() async throws {
    let startDate = Date(timeIntervalSince1970: 200)
    let cursor = BriteLogOSLogCursor(
        fetchRecords: { _ in
            [
                .init(
                    date: startDate,
                    level: .info,
                    subsystem: "com.gaelic-ghost.demo",
                    category: "rendering",
                    process: "DemoApp",
                    processIdentifier: 7,
                    sender: "DemoApp",
                    message: "skip me",
                ),
                .init(
                    date: startDate.addingTimeInterval(1),
                    level: .error,
                    subsystem: "com.gaelic-ghost.demo",
                    category: "rendering",
                    process: "DemoApp",
                    processIdentifier: 7,
                    sender: "DemoApp",
                    message: "fatal issue",
                ),
            ]
        },
        startDate: startDate,
        filter: .init(messageContains: "fatal", minimumLevel: .error),
    )

    let batch = try await cursor.nextBatch()

    #expect(batch.count == 1)
    #expect(batch.first?.message == "fatal issue")
    #expect(batch.first?.level == .error)
}
