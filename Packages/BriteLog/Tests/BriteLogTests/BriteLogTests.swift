import ArgumentParser
import Testing
@testable import BriteLog
import BriteLogCore

@Test func watchPlanCarriesChosenPresentationDefaults() async throws {
    let plan = BriteLog.WatchPlan(
        source: .oslogStore,
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
        pollIntervalSeconds: 1
    )

    #expect(plan.source == .oslogStore)
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

@Test func themeListStaysStableForCliParsing() async throws {
    #expect(BriteLog.Theme.allCases.map(\.rawValue) == ["xcode", "neon", "plain"])
    #expect(BriteLog.MetadataMode.allCases.map(\.rawValue) == ["full", "compact", "hidden"])
    #expect(BriteLog.Level.allCases.map(\.rawValue) == ["trace", "debug", "info", "notice", "warning", "error", "fault", "critical"])
    #expect(BriteLog.Source.allCases.map(\.rawValue) == ["oslog-store"])
    #expect(BriteLog.Scope.allCases.map(\.rawValue) == ["current-process", "local-store"])
}

@Test func bundleIdentifierResolvesToSubsystemFilter() async throws {
    #expect(try BriteLog.Watch.resolvedSubsystem(subsystem: nil, bundleIdentifier: "com.gaelic-ghost.demo") == "com.gaelic-ghost.demo")
    #expect(try BriteLog.Watch.resolvedSubsystem(subsystem: "com.gaelic-ghost.demo", bundleIdentifier: nil) == "com.gaelic-ghost.demo")
    #expect(try BriteLog.Watch.resolvedSubsystem(subsystem: "com.gaelic-ghost.demo", bundleIdentifier: "com.gaelic-ghost.demo") == "com.gaelic-ghost.demo")
}

@Test func conflictingBundleIdentifierAndSubsystemAreRejected() async throws {
    #expect(throws: ValidationError.self) {
        _ = try BriteLog.Watch.resolvedSubsystem(
            subsystem: "com.gaelic-ghost.one",
            bundleIdentifier: "com.gaelic-ghost.two"
        )
    }
}

@Test func filterMatchesOnlyRequestedFields() async throws {
    let record = BriteLogRecord(
        date: .init(timeIntervalSince1970: 100),
        level: .notice,
        subsystem: "com.gaelic-ghost.demo",
        category: "rendering",
        process: "DemoApp",
        processIdentifier: 7,
        sender: "DemoApp",
        message: "Rendered line"
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

@Test func rendererKeepsPlainThemeReadable() async throws {
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
            message: "Watch this line"
        )
    )

    #expect(rendered.contains("WARNING"))
    #expect(rendered.contains("[DemoApp DemoApp Helper com.gaelic-ghost.demo:rendering]"))
    #expect(rendered.contains("Watch this line"))
    #expect(!rendered.contains("\u{001B}["))
}

@Test func focusConstraintReflectsCrossProcessTargeting() async throws {
    #expect(!BriteLogFilter().hasFocusConstraint)
    #expect(BriteLogFilter(subsystem: "com.gaelic-ghost.demo").hasFocusConstraint)
    #expect(BriteLogFilter(sender: "DemoApp").hasFocusConstraint)
    #expect(BriteLogFilter(messageContains: "fatal").hasFocusConstraint)
}
