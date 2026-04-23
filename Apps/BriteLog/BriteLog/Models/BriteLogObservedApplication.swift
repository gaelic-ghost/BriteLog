import Foundation

struct BriteLogObservedApplication: Equatable {
    enum Phase: String, Equatable {
        case waitingForLaunch
        case running
        case terminated
    }

    var bundleIdentifier: String
    var localizedName: String?
    var processIdentifier: Int32?
    var phase: Phase
    var updatedAt: Date
}
