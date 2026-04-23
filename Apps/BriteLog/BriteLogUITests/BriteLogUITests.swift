import XCTest

final class BriteLogUITests: XCTestCase {
    override func setUpWithError() {
        continueAfterFailure = false
    }

    @MainActor
    func testExample() {
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
