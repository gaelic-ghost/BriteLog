//
//  BriteLogTestDummyUITests.swift
//  BriteLogTestDummyUITests
//
//  Created by Gale Williams on 4/23/26.
//

import XCTest

final class BriteLogTestDummyUITests: XCTestCase {
    private enum AccessibilityID {
        static let networkTimeoutButton = "fixture-network-timeout-button"
        static let retryBurstButton = "fixture-retry-burst-button"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFixtureButtonsUpdateVisibleState() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Emitted a launch and scene-activation checkpoint."].waitForExistence(timeout: 2)
        )

        app.buttons[AccessibilityID.networkTimeoutButton].click()
        XCTAssertTrue(
            app.staticTexts["Emitted a warning and error in the network subsystem."].waitForExistence(timeout: 2)
        )

        XCTAssertTrue(app.staticTexts["Burst counter: 0"].exists)

        app.buttons[AccessibilityID.retryBurstButton].click()
        XCTAssertTrue(
            app.staticTexts["Emitted a retry burst in the network retries category."].waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.staticTexts["Burst counter: 1"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
