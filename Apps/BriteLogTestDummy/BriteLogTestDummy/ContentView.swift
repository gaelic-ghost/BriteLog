//
//  ContentView.swift
//  BriteLogTestDummy
//
//  Created by Gale Williams on 4/23/26.
//

import OSLog
import SwiftUI

private enum FixtureLogger {
    static let lifecycle = Logger(
        subsystem: "com.galewilliams.BriteLogTestDummy.app",
        category: "lifecycle"
    )
    static let network = Logger(
        subsystem: "com.galewilliams.BriteLogTestDummy.network",
        category: "requests"
    )
    static let networkRetry = Logger(
        subsystem: "com.galewilliams.BriteLogTestDummy.network",
        category: "retries"
    )
    static let auth = Logger(
        subsystem: "com.galewilliams.BriteLogTestDummy.auth",
        category: "session"
    )
    static let render = Logger(
        subsystem: "com.galewilliams.BriteLogTestDummy.ui",
        category: "rendering"
    )
}

struct ContentView: View {
    private enum AccessibilityID {
        static let latestActionText = "fixture-latest-action-text"
        static let burstCounterText = "fixture-burst-counter-text"
        static let launchCheckpointButton = "fixture-launch-checkpoint-button"
        static let networkTimeoutButton = "fixture-network-timeout-button"
        static let authFailureButton = "fixture-auth-failure-button"
        static let renderHitchButton = "fixture-render-hitch-button"
        static let retryBurstButton = "fixture-retry-burst-button"
        static let mixedBurstButton = "fixture-mixed-burst-button"
    }

    @State private var burstCounter = 0
    @State private var lastActionDescription = "Press any fixture button to emit a predictable set of logs."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                suggestedRules
                scenarioButtons
                currentState
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(24)
        }
        .frame(minWidth: 760, minHeight: 560)
        .onAppear {
            emitLaunchSequence()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("BriteLog Test Dummy", systemImage: "testtube.2")
                .font(.largeTitle.weight(.bold))

            Text("A small macOS app built specifically to exercise BriteLog’s Xcode integration, live viewer, saved highlight rules, and subsystem or category targeting.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var suggestedRules: some View {
        GroupBox("Suggested BriteLog Rules To Try") {
            VStack(alignment: .leading, spacing: 10) {
                Text("These are good first saved-rule or filter targets once the viewer is attached:")
                    .foregroundStyle(.secondary)

                Text("Text: `fixture network timeout`")
                    .font(.body.monospaced())
                Text("Subsystem: `com.galewilliams.BriteLogTestDummy.network`")
                    .font(.body.monospaced())
                Text("Category: `retries`")
                    .font(.body.monospaced())
                Text("Minimum level: `WARNING`")
                    .font(.body.monospaced())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var scenarioButtons: some View {
        GroupBox("Fixture Log Scenarios") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Each button emits a targeted scenario with stable wording so you can test search, saved highlight rules, subsystem or category filters, and the floating viewer layout.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Emit Launch Checkpoint") {
                        emitLaunchSequence()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(AccessibilityID.launchCheckpointButton)

                    Button("Emit Network Timeout") {
                        emitNetworkTimeout()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(AccessibilityID.networkTimeoutButton)

                    Button("Emit Auth Failure") {
                        emitAuthenticationFailure()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(AccessibilityID.authFailureButton)
                }

                HStack(spacing: 12) {
                    Button("Emit Render Hitch") {
                        emitRenderWarning()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(AccessibilityID.renderHitchButton)

                    Button("Emit Retry Burst") {
                        emitRetryBurst()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(AccessibilityID.retryBurstButton)

                    Button("Emit Mixed Demo Burst") {
                        emitMixedBurst()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(AccessibilityID.mixedBurstButton)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var currentState: some View {
        GroupBox("Latest Fixture Action") {
            VStack(alignment: .leading, spacing: 8) {
                Text(lastActionDescription)
                    .textSelection(.enabled)
                    .accessibilityIdentifier(AccessibilityID.latestActionText)

                Text("Burst counter: \(burstCounter)")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityID.burstCounterText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func emitLaunchSequence() {
        FixtureLogger.lifecycle.notice("fixture app launch checkpoint reached")
        FixtureLogger.lifecycle.info("fixture scene became active in the primary window")
        lastActionDescription = "Emitted a launch and scene-activation checkpoint."
    }

    private func emitNetworkTimeout() {
        FixtureLogger.network.warning("fixture network timeout while loading dashboard summary")
        FixtureLogger.network.error("fixture network timeout escalated after request deadline elapsed")
        lastActionDescription = "Emitted a warning and error in the network subsystem."
    }

    private func emitAuthenticationFailure() {
        FixtureLogger.auth.notice("fixture authentication refresh started for demo account")
        FixtureLogger.auth.error("fixture auth rejection due to stale session token")
        lastActionDescription = "Emitted an auth flow with a final session error."
    }

    private func emitRenderWarning() {
        FixtureLogger.render.notice("fixture render pass started for dashboard list")
        FixtureLogger.render.warning("fixture render hitch while diffing 240 visible rows")
        lastActionDescription = "Emitted a UI rendering notice and warning."
    }

    private func emitRetryBurst() {
        burstCounter += 1

        FixtureLogger.networkRetry.debug("fixture retry burst \(burstCounter) queued request one")
        FixtureLogger.networkRetry.info("fixture retry burst \(burstCounter) scheduled backoff 0.25 seconds")
        FixtureLogger.networkRetry.notice("fixture retry burst \(burstCounter) scheduled backoff 0.50 seconds")
        FixtureLogger.networkRetry.warning("fixture retry burst \(burstCounter) reached warning threshold after repeated failures")

        lastActionDescription = "Emitted a retry burst in the network retries category."
    }

    private func emitMixedBurst() {
        burstCounter += 1

        FixtureLogger.lifecycle.debug("fixture mixed burst \(burstCounter) entered demo flow")
        FixtureLogger.network.info("fixture mixed burst \(burstCounter) loaded cached profile")
        FixtureLogger.auth.warning("fixture mixed burst \(burstCounter) detected a session refresh requirement")
        FixtureLogger.render.error("fixture mixed burst \(burstCounter) hit a presentation mismatch while rendering")

        lastActionDescription = "Emitted a mixed burst across lifecycle, network, auth, and UI subsystems."
    }
}

#Preview {
    ContentView()
}
