import Testing
@testable import BriteLog

@Test func watchPlanCarriesChosenPresentationDefaults() async throws {
    let plan = BriteLog.WatchPlan(
        subsystem: "com.gaelic-ghost.demo",
        category: "rendering",
        theme: .xcode,
        metadataMode: .compact,
        persistHighlights: true,
        simplifyOutput: true
    )

    #expect(plan.subsystem == "com.gaelic-ghost.demo")
    #expect(plan.category == "rendering")
    #expect(plan.theme == .xcode)
    #expect(plan.metadataMode == .compact)
    #expect(plan.persistHighlights)
    #expect(plan.simplifyOutput)
}

@Test func themeListStaysStableForCliParsing() async throws {
    #expect(BriteLog.Theme.allCases.map(\.rawValue) == ["xcode", "neon", "plain"])
    #expect(BriteLog.MetadataMode.allCases.map(\.rawValue) == ["full", "compact", "hidden"])
}
