import Combine
import Foundation
import TimetrackerCore

/// Drives `TimerSession` from the UI: owns the tick timer and publishes the clock.
@MainActor
final class TimerManager: ObservableObject {
    static let shared = TimerManager()

    @Published private(set) var session = TimerSession()
    @Published private(set) var elapsedSeconds: TimeInterval = 0

    private var ticker: Timer?

    var isRunning: Bool { session.isRunning }
    var isPaused: Bool { session.isPaused }
    var isLogging: Bool { session.isLogging }
    var hasActiveSession: Bool { session.hasActiveSession }
    var formattedTime: String { DurationFormat.clock(elapsedSeconds) }

    var pendingRange: (start: Date, end: Date)? { session.pendingRange }

    func start(at date: Date = Date()) {
        guard session.start(at: date) else { return }
        elapsedSeconds = 0
        startTicker()
    }

    func pause(at date: Date = Date()) {
        guard session.pause(at: date) else { return }
        stopTicker()
        elapsedSeconds = session.elapsed(at: date)
    }

    func resume(at date: Date = Date()) {
        guard session.resume(at: date) else { return }
        elapsedSeconds = session.elapsed(at: date)
        startTicker()
    }

    /// Ends the session and opens the note form.
    func finish(at date: Date = Date()) {
        guard session.finish(at: date) else { return }
        stopTicker()
        elapsedSeconds = session.elapsed(at: date)
    }

    /// Note saved — back to idle with a clean clock.
    func finishLogging() {
        resetToIdle()
    }

    /// Note abandoned or active session dropped.
    func discard() {
        resetToIdle()
    }

    func makeEntry(note: String) -> WorkEntry? {
        session.makeEntry(note: note)
    }

    private func resetToIdle() {
        stopTicker()
        session.discard()
        elapsedSeconds = 0
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        timer.tolerance = 0.05
        // `.common` keeps the clock moving while the menu bar panel tracks events.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard session.isRunning else { return }
        elapsedSeconds = session.elapsed(at: Date())
    }
}
