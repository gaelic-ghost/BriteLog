import AppKit
import Foundation

struct BriteLogXcodeLifecycleCoordinator {
    struct RunningApplicationHandle {
        var bundleIdentifier: String?
        var bundleURL: URL?
        var isTerminated: @Sendable () -> Bool
        var terminate: @Sendable () -> Bool
    }

    typealias RunningApplicationsProvider = @Sendable () -> [RunningApplicationHandle]
    typealias ApplicationURLResolver = @Sendable (_ bundleIdentifier: String) -> URL?
    typealias ApplicationLauncher = @Sendable (_ applicationURL: URL) async throws -> Void
    typealias Sleep = @Sendable (_ duration: Duration) async throws -> Void

    nonisolated static let xcodeBundleIdentifier = "com.apple.dt.Xcode"

    nonisolated let runningApplications: RunningApplicationsProvider
    nonisolated let resolveApplicationURL: ApplicationURLResolver
    nonisolated let launchApplication: ApplicationLauncher
    nonisolated let sleep: Sleep
    nonisolated let terminationTimeout: Duration
    nonisolated let pollInterval: Duration

    nonisolated init(
        runningApplications: @escaping RunningApplicationsProvider = Self.defaultRunningApplications,
        resolveApplicationURL: @escaping ApplicationURLResolver = Self.defaultApplicationURLResolver,
        launchApplication: @escaping ApplicationLauncher = Self.defaultApplicationLauncher,
        sleep: @escaping Sleep = Self.defaultSleep,
        terminationTimeout: Duration = .seconds(15),
        pollInterval: Duration = .milliseconds(200),
    ) {
        self.runningApplications = runningApplications
        self.resolveApplicationURL = resolveApplicationURL
        self.launchApplication = launchApplication
        self.sleep = sleep
        self.terminationTimeout = terminationTimeout
        self.pollInterval = pollInterval
    }

    nonisolated static func defaultRunningApplications() -> [RunningApplicationHandle] {
        NSWorkspace.shared.runningApplications.map { application in
            RunningApplicationHandle(
                bundleIdentifier: application.bundleIdentifier,
                bundleURL: application.bundleURL,
                isTerminated: { application.isTerminated },
                terminate: { application.terminate() },
            )
        }
    }

    nonisolated static func defaultApplicationURLResolver(bundleIdentifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    nonisolated static func defaultApplicationLauncher(applicationURL: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, error in
                if let error {
                    continuation.resume(throwing: BriteLogXcodeLifecycleError(
                        """
                        BriteLog applied the scheme change, but it could not relaunch Xcode automatically.
                        Xcode app:
                        \(applicationURL.path)

                        Underlying error:
                        \(error.localizedDescription)
                        """,
                    ))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    nonisolated static func defaultSleep(duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }

    nonisolated func closeXcodeIfRunning() async throws -> URL? {
        let xcodeApplications = runningApplications()
            .filter { $0.bundleIdentifier == Self.xcodeBundleIdentifier && !$0.isTerminated() }

        guard !xcodeApplications.isEmpty else {
            return nil
        }
        guard let xcodeURL = xcodeApplications.lazy.compactMap(\.bundleURL).first
            ?? resolveApplicationURL(Self.xcodeBundleIdentifier) else {
            throw BriteLogXcodeLifecycleError(
                """
                BriteLog found a running Xcode process, but it could not resolve the Xcode app bundle URL to reopen afterward.
                """,
            )
        }

        for application in xcodeApplications {
            guard application.terminate() else {
                throw BriteLogXcodeLifecycleError(
                    """
                    BriteLog asked Xcode to quit so it could update the shared scheme safely, but the quit request was not accepted.
                    Close Xcode manually, then try again.
                    """,
                )
            }
        }

        try await waitForTermination(of: xcodeApplications)
        return xcodeURL
    }

    nonisolated func reopenXcodeIfNeeded(at applicationURL: URL?) async throws {
        guard let applicationURL else {
            return
        }

        try await launchApplication(applicationURL)
    }

    private nonisolated func waitForTermination(
        of applications: [RunningApplicationHandle],
    ) async throws {
        let timeoutDeadline = ContinuousClock.now + terminationTimeout

        while applications.contains(where: { !$0.isTerminated() }) {
            if ContinuousClock.now >= timeoutDeadline {
                throw BriteLogXcodeLifecycleError(
                    """
                    BriteLog asked Xcode to quit, but Xcode did not finish closing before the safety timeout expired.
                    Wait for Xcode to close completely, then try again.
                    """,
                )
            }

            try await sleep(pollInterval)
        }
    }
}

private struct BriteLogXcodeLifecycleError: LocalizedError {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
