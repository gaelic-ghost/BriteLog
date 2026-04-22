import Testing
@testable import BriteLog
import BriteLogCore

@Test func watchPlanCarriesChosenPresentationDefaults() async throws {
    let plan = BriteLog.WatchPlan(
        source: .oslogStore,
        subsystem: "com.gaelic-ghost.demo",
        category: "rendering",
        process: "DemoApp",
        processIdentifier: 42,
        theme: .xcode,
        metadataMode: .compact,
        persistHighlights: true,
        simplifyOutput: true,
        lookbackSeconds: 5,
        pollIntervalSeconds: 1
    )

    #expect(plan.source == .oslogStore)
    #expect(plan.subsystem == "com.gaelic-ghost.demo")
    #expect(plan.category == "rendering")
    #expect(plan.process == "DemoApp")
    #expect(plan.processIdentifier == 42)
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
    #expect(BriteLog.Source.allCases.map(\.rawValue) == ["oslog-store"])
    #expect(BriteLog.Scope.allCases.map(\.rawValue) == ["current-process", "local-store"])
}

@Test func filterMatchesOnlyRequestedFields() async throws {
    let record = BriteLogRecord(
        date: .init(timeIntervalSince1970: 100),
        level: .notice,
        subsystem: "com.gaelic-ghost.demo",
        category: "rendering",
        process: "DemoApp",
        processIdentifier: 7,
        message: "Rendered line"
    )

    #expect(BriteLogFilter(subsystem: "com.gaelic-ghost.demo").matches(record))
    #expect(BriteLogFilter(category: "rendering").matches(record))
    #expect(BriteLogFilter(process: "DemoApp").matches(record))
    #expect(BriteLogFilter(processIdentifier: 7).matches(record))
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
            message: "Watch this line"
        )
    )

    #expect(rendered.contains("WARNING"))
    #expect(rendered.contains("[DemoApp com.gaelic-ghost.demo:rendering]"))
    #expect(rendered.contains("Watch this line"))
    #expect(!rendered.contains("\u{001B}["))
}
