import Foundation
import Testing
@testable import TimetrackerCore

@Suite("TimerSession")
struct TimerSessionTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    @Test("A fresh session is idle with a zeroed clock")
    func startsIdle() {
        let session = TimerSession()

        #expect(session.state == .idle)
        #expect(session.isRunning == false)
        #expect(session.isLogging == false)
        #expect(session.pendingRange == nil)
        #expect(session.elapsed(at: start) == 0)
    }

    @Test("Starting moves idle to running and the clock follows the date")
    func startFromIdle() {
        var session = TimerSession()

        #expect(session.start(at: start) == true)
        #expect(session.state == .running(since: start))
        #expect(session.isRunning == true)
        #expect(session.elapsed(at: start.addingTimeInterval(90)) == 90)
    }

    @Test("Starting twice is ignored and keeps the original start date")
    func startIsIdempotent() {
        var session = TimerSession()
        session.start(at: start)

        #expect(session.start(at: start.addingTimeInterval(60)) == false)
        #expect(session.state == .running(since: start))
    }

    @Test("Stopping moves running to logging and freezes the clock")
    func stopFromRunning() {
        var session = TimerSession()
        session.start(at: start)
        let end = start.addingTimeInterval(125)

        #expect(session.stop(at: end) == true)
        #expect(session.state == .logging(start: start, end: end))
        #expect(session.isRunning == false)
        #expect(session.isLogging == true)
        #expect(session.pendingRange?.start == start)
        #expect(session.pendingRange?.end == end)
        #expect(session.elapsed(at: end.addingTimeInterval(500)) == 125)
    }

    @Test("Stopping is ignored when not running")
    func stopRequiresRunning() {
        var idle = TimerSession()
        #expect(idle.stop(at: start) == false)
        #expect(idle.state == .idle)

        var logging = TimerSession()
        logging.start(at: start)
        logging.stop(at: start.addingTimeInterval(10))
        let stateBefore = logging.state

        #expect(logging.stop(at: start.addingTimeInterval(20)) == false)
        #expect(logging.state == stateBefore)
    }

    @Test("Starting is ignored while a note is pending")
    func startIgnoredWhileLogging() {
        var session = TimerSession()
        session.start(at: start)
        session.stop(at: start.addingTimeInterval(10))

        #expect(session.start(at: start.addingTimeInterval(20)) == false)
        #expect(session.isLogging == true)
    }

    @Test("A stop date before the start date clamps to a zero-length range")
    func stopClampsToStart() {
        var session = TimerSession()
        session.start(at: start)

        session.stop(at: start.addingTimeInterval(-60))

        #expect(session.state == .logging(start: start, end: start))
        #expect(session.elapsed(at: start) == 0)
    }

    @Test("Discarding returns to idle from any state")
    func discardReturnsToIdle() {
        var session = TimerSession()
        session.start(at: start)
        session.stop(at: start.addingTimeInterval(30))

        session.discard()

        #expect(session.state == .idle)
        #expect(session.elapsed(at: start.addingTimeInterval(60)) == 0)
    }

    @Test("Logging builds an entry with the pending range and a trimmed note")
    func makeEntryFromLogging() throws {
        var session = TimerSession()
        session.start(at: start)
        let end = start.addingTimeInterval(45)
        session.stop(at: end)

        let entry = try #require(session.makeEntry(note: "  Wrote tests \n"))

        #expect(entry.startDate == start)
        #expect(entry.endDate == end)
        #expect(entry.note == "Wrote tests")
        #expect(entry.duration == 45)
    }

    @Test("No entry without a note or outside the logging state")
    func makeEntryRequiresNoteAndLoggingState() {
        var session = TimerSession()
        #expect(session.makeEntry(note: "Idle work") == nil)

        session.start(at: start)
        #expect(session.makeEntry(note: "Running work") == nil)

        session.stop(at: start.addingTimeInterval(10))
        #expect(session.makeEntry(note: "") == nil)
        #expect(session.makeEntry(note: "   \n\t ") == nil)
        #expect(session.makeEntry(note: "Real work") != nil)
    }

    @Test("A full cycle ends back at idle")
    func fullCycle() {
        var session = TimerSession()
        session.start(at: start)
        session.stop(at: start.addingTimeInterval(60))
        _ = session.makeEntry(note: "Done")
        session.discard()

        #expect(session.state == .idle)
        #expect(session.start(at: start.addingTimeInterval(120)) == true)
    }
}

@Suite("DurationFormat")
struct DurationFormatTests {
    @Test("Clock strings switch to hours only when needed")
    func clock() {
        #expect(DurationFormat.clock(0) == "00:00")
        #expect(DurationFormat.clock(9) == "00:09")
        #expect(DurationFormat.clock(65) == "01:05")
        #expect(DurationFormat.clock(3599) == "59:59")
        #expect(DurationFormat.clock(3600) == "1:00:00")
        #expect(DurationFormat.clock(7325) == "2:02:05")
        #expect(DurationFormat.clock(-5) == "00:00")
    }

    @Test("Compact strings read like a day total")
    func compact() {
        #expect(DurationFormat.compact(42) == "42s")
        #expect(DurationFormat.compact(900) == "15m")
        #expect(DurationFormat.compact(3600) == "1h")
        #expect(DurationFormat.compact(8100) == "2h 15m")
    }
}
