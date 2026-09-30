import Foundation

/// Pure state machine behind the timer. Holds no timers and no storage, so every
/// transition is directly testable.
///
/// `idle → running → logging → idle`
public struct TimerSession: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// Nothing tracked, waiting for a start.
        case idle
        /// Tracking since the given date.
        case running(since: Date)
        /// Stopped; waiting for the note that turns the range into a `WorkEntry`.
        case logging(start: Date, end: Date)
    }

    public private(set) var state: State

    public init() {
        state = .idle
    }

    public var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    public var isLogging: Bool {
        if case .logging = state { return true }
        return false
    }

    /// The range waiting for a note, if any.
    public var pendingRange: (start: Date, end: Date)? {
        if case let .logging(start, end) = state { return (start, end) }
        return nil
    }

    /// Seconds on the clock: live while running, frozen while logging, zero when idle.
    public func elapsed(at date: Date) -> TimeInterval {
        switch state {
        case .idle:
            return 0
        case let .running(since):
            return max(0, date.timeIntervalSince(since))
        case let .logging(start, end):
            return max(0, end.timeIntervalSince(start))
        }
    }

    /// Starts tracking. Returns `false` when the session was not idle.
    @discardableResult
    public mutating func start(at date: Date = Date()) -> Bool {
        guard case .idle = state else { return false }
        state = .running(since: date)
        return true
    }

    /// Ends tracking and moves to note entry. Returns `false` when not running.
    @discardableResult
    public mutating func stop(at date: Date = Date()) -> Bool {
        guard case let .running(since) = state else { return false }
        state = .logging(start: since, end: max(since, date))
        return true
    }

    /// Throws the pending range away and returns to idle.
    public mutating func discard() {
        state = .idle
    }

    /// Builds the entry for the pending range. `nil` when not logging or when the
    /// note is blank — an entry always carries a note.
    public func makeEntry(note: String) -> WorkEntry? {
        guard case let .logging(start, end) = state else { return nil }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return WorkEntry(startDate: start, endDate: end, note: trimmed)
    }
}
