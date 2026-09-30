import Foundation

/// Pure state machine behind the timer. Holds no timers and no storage, so every
/// transition is directly testable.
///
/// `idle → running ⇄ paused → logging → idle`
public struct TimerSession: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// Nothing tracked, waiting for a start.
        case idle
        /// Tracking. `sessionStart` is when the user first pressed Start;
        /// `segmentStart` is when the current running stretch began;
        /// `priorElapsed` is time already banked from earlier pauses.
        case running(sessionStart: Date, segmentStart: Date, priorElapsed: TimeInterval)
        /// Paused with time on the clock. Resume continues; finish logs.
        case paused(sessionStart: Date, elapsed: TimeInterval)
        /// Finished; waiting for the note that turns the range into a `WorkEntry`.
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

    public var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    public var isLogging: Bool {
        if case .logging = state { return true }
        return false
    }

    /// True when a session is in progress (running or paused) and can be finished.
    public var hasActiveSession: Bool {
        switch state {
        case .running, .paused: return true
        case .idle, .logging: return false
        }
    }

    /// The range waiting for a note, if any.
    public var pendingRange: (start: Date, end: Date)? {
        if case let .logging(start, end) = state { return (start, end) }
        return nil
    }

    /// Seconds on the clock: live while running, frozen while paused/logging, zero when idle.
    public func elapsed(at date: Date) -> TimeInterval {
        switch state {
        case .idle:
            return 0
        case let .running(_, segmentStart, priorElapsed):
            return max(0, priorElapsed + date.timeIntervalSince(segmentStart))
        case let .paused(_, elapsed):
            return max(0, elapsed)
        case let .logging(start, end):
            return max(0, end.timeIntervalSince(start))
        }
    }

    /// Starts tracking. Returns `false` when the session was not idle.
    @discardableResult
    public mutating func start(at date: Date = Date()) -> Bool {
        guard case .idle = state else { return false }
        state = .running(sessionStart: date, segmentStart: date, priorElapsed: 0)
        return true
    }

    /// Pauses a running session. Returns `false` when not running.
    @discardableResult
    public mutating func pause(at date: Date = Date()) -> Bool {
        guard case let .running(sessionStart, segmentStart, priorElapsed) = state else {
            return false
        }
        let elapsed = max(0, priorElapsed + date.timeIntervalSince(segmentStart))
        state = .paused(sessionStart: sessionStart, elapsed: elapsed)
        return true
    }

    /// Continues a paused session. Returns `false` when not paused.
    @discardableResult
    public mutating func resume(at date: Date = Date()) -> Bool {
        guard case let .paused(sessionStart, elapsed) = state else { return false }
        state = .running(
            sessionStart: sessionStart,
            segmentStart: date,
            priorElapsed: elapsed
        )
        return true
    }

    /// Ends the session and moves to note entry from running or paused.
    /// Returns `false` when there is nothing to finish.
    @discardableResult
    public mutating func finish(at date: Date = Date()) -> Bool {
        switch state {
        case let .running(sessionStart, segmentStart, priorElapsed):
            let elapsed = max(0, priorElapsed + date.timeIntervalSince(segmentStart))
            let end = sessionStart.addingTimeInterval(elapsed)
            state = .logging(start: sessionStart, end: max(sessionStart, end))
            return true
        case let .paused(sessionStart, elapsed):
            let end = sessionStart.addingTimeInterval(max(0, elapsed))
            state = .logging(start: sessionStart, end: max(sessionStart, end))
            return true
        case .idle, .logging:
            return false
        }
    }

    /// Throws the pending range (or active session) away and returns to idle.
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
