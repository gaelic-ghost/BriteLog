import ArgumentParser
@testable import BriteLogCLI
import BriteLogCore
import Foundation
import Testing

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

@Test func `focus constraint reflects cross process targeting`() {
    #expect(!BriteLogFilter().hasFocusConstraint)
    #expect(BriteLogFilter(subsystem: "com.gaelic-ghost.demo").hasFocusConstraint)
    #expect(BriteLogFilter(sender: "DemoApp").hasFocusConstraint)
    #expect(BriteLogFilter(messageContains: "fatal").hasFocusConstraint)
}
