import Foundation

/// A single finished tracking session with the note the user wrote for it.
public struct WorkEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var startDate: Date
    public var endDate: Date
    public var note: String

    public init(id: UUID = UUID(), startDate: Date, endDate: Date, note: String) {
        self.id = id
        self.startDate = startDate
        self.endDate = max(startDate, endDate)
        self.note = note
    }

    public var duration: TimeInterval { endDate.timeIntervalSince(startDate) }

    public var formattedDuration: String { DurationFormat.clock(duration) }
}

/// Duration strings shared by the timer panel, the history table and the tests.
public enum DurationFormat {
    /// `mm:ss` below an hour, `h:mm:ss` above it.
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// Human summary used for day totals: `2h 15m`, `15m`, `42s`.
    public static func compact(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(total)s"
    }
}
