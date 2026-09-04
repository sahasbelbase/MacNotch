import Foundation

/// Defines how clipboard duplicates are handled.
public enum ClipboardDuplicatePolicy: String, CaseIterable, Identifiable, Codable, Sendable {
    case moveToTop = "Move existing duplicate to top"
    case keepEvery = "Keep every copy"

    public var id: String { rawValue }

    public var shortTitle: String {
        switch self {
        case .moveToTop: return "Move to Top"
        case .keepEvery: return "Keep Every"
        }
    }
}
