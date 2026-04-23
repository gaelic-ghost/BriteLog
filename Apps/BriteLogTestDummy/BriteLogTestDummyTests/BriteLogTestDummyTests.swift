//
//  BriteLogTestDummyTests.swift
//  BriteLogTestDummyTests
//
//  Created by Gale Williams on 4/23/26.
//

import Foundation
import Testing
@testable import BriteLogTestDummy

struct BriteLogTestDummyTests {
    @Test
    func appBundleIdentifierMatchesTheFixtureTarget() {
        #expect(Bundle.main.bundleIdentifier == "com.galewilliams.BriteLogTestDummy")
    }
}
