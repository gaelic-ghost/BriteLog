import Foundation
import OSLog

import BriteLogCore

public enum BriteLogOSLogStoreScope: String, CaseIterable, Sendable {
    case currentProcess = "current-process"
    case localStore = "local-store"
}

public struct BriteLogOSLogStoreSource: BriteLogLiveSource {
    public enum SourceError: LocalizedError {
        case localStoreUnavailable(underlying: Error)

        public var errorDescription: String? {
            switch self {
            case let .localStoreUnavailable(underlying):
                """
                BriteLog could not open the macOS local unified log store. Apple documents that `OSLogStore.local()`
                requires system permission and the `com.apple.logging.local-store` entitlement. Underlying error:
                \(underlying.localizedDescription)
                """
            }
        }
    }

    public var scope: BriteLogOSLogStoreScope

    public init(scope: BriteLogOSLogStoreScope) {
        self.scope = scope
    }

    public func liveEntries(
        matching request: BriteLogLiveRequest
    ) throws -> AsyncThrowingStream<BriteLogRecord, Error> {
        let store = try makeStore()
        let startDate = resolveStartDate(request.start)
        let cursor = Cursor(
            store: store,
            startDate: startDate,
            filter: request.filter
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    while !Task.isCancelled {
                        for record in try await cursor.nextBatch() {
                            continuation.yield(record)
                        }

                        try await Task.sleep(for: request.pollInterval)
                    }

                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func makeStore() throws -> OSLogStore {
        switch scope {
        case .currentProcess:
            return try OSLogStore(scope: .currentProcessIdentifier)
        case .localStore:
            do {
                return try OSLogStore.local()
            } catch {
                throw SourceError.localStoreUnavailable(underlying: error)
            }
        }
    }

    private func resolveStartDate(_ start: BriteLogLiveRequest.Start) -> Date {
        switch start {
        case .now:
            Date()
        case let .secondsBack(seconds):
            Date().addingTimeInterval(-seconds)
        case let .date(date):
            date
        }
    }
}

private actor Cursor {
    let store: OSLogStore
    let filter: BriteLogFilter
    var cursorDate: Date
    var trailingFingerprints = Set<BriteLogRecord.Fingerprint>()

    init(
        store: OSLogStore,
        startDate: Date,
        filter: BriteLogFilter
    ) {
        self.store = store
        self.filter = filter
        cursorDate = startDate
    }

    func nextBatch() throws -> [BriteLogRecord] {
        let position = store.position(date: cursorDate)
        let entries = try store.getEntries(at: position)
        var records: [BriteLogRecord] = []

        for case let entry as OSLogEntryLog in entries {
            let level: BriteLogRecord.Level
            switch entry.level {
            case .undefined:
                level = .undefined
            case .debug:
                level = .debug
            case .info:
                level = .info
            case .notice:
                level = .notice
            case .error:
                level = .error
            case .fault:
                level = .fault
            @unknown default:
                level = .undefined
            }
            let message = entry.composedMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            let record = BriteLogRecord(
                date: entry.date,
                level: level,
                subsystem: entry.subsystem,
                category: entry.category,
                process: entry.process,
                processIdentifier: entry.processIdentifier,
                message: message.isEmpty ? "<empty log message>" : message
            )

            guard filter.matches(record) else {
                continue
            }
            guard record.date >= cursorDate else {
                continue
            }

            let fingerprint = record.fingerprint
            if record.date == cursorDate, trailingFingerprints.contains(fingerprint) {
                continue
            }

            records.append(record)

            if record.date > cursorDate {
                cursorDate = record.date
                trailingFingerprints = [fingerprint]
            } else {
                trailingFingerprints.insert(fingerprint)
            }
        }

        return records
    }
}
