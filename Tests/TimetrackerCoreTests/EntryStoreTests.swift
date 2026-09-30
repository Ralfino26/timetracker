import Foundation
import Testing
@testable import TimetrackerCore

/// A throwaway directory per test so stores never share state.
private final class TemporaryDirectory {
    let url: URL

    init() throws {
        url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("timetracker-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

/// UTC keeps day bucketing deterministic wherever the tests run.
private let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
}()

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    guard let date = utcCalendar.date(from: components) else {
        fatalError("Invalid test date")
    }
    return date
}

@Suite("EntryStore")
struct EntryStoreTests {
    @Test("A store in an empty directory starts with no entries")
    @MainActor
    func emptyDirectory() throws {
        let directory = try TemporaryDirectory()
        let store = EntryStore(directory: directory.url, calendar: utcCalendar)

        #expect(store.entries.isEmpty)
        #expect(store.lastErrorMessage == nil)
        #expect(FileManager.default.fileExists(atPath: store.fileURL.path) == false)
    }

    @Test("Entries survive a reload from disk")
    @MainActor
    func roundTrip() throws {
        let directory = try TemporaryDirectory()
        let first = WorkEntry(
            startDate: date(2026, 3, 10, 9, 0),
            endDate: date(2026, 3, 10, 10, 30),
            note: "Design review"
        )
        let second = WorkEntry(
            startDate: date(2026, 3, 11, 13, 15),
            endDate: date(2026, 3, 11, 14, 0),
            note: "Bug triage"
        )

        let store = EntryStore(directory: directory.url, calendar: utcCalendar)
        try store.add(first)
        try store.add(second)

        #expect(FileManager.default.fileExists(atPath: store.fileURL.path))

        let reloaded = EntryStore(directory: directory.url, calendar: utcCalendar)

        #expect(reloaded.entries == [second, first])
        #expect(reloaded.entries.first?.note == "Bug triage")
        #expect(reloaded.entries.last?.duration == 5400)
    }

    @Test("Entries are kept newest first")
    @MainActor
    func sortedNewestFirst() throws {
        let directory = try TemporaryDirectory()
        let store = EntryStore(directory: directory.url, calendar: utcCalendar)

        try store.add(startDate: date(2026, 3, 1, 8, 0), endDate: date(2026, 3, 1, 9, 0), note: "A")
        try store.add(startDate: date(2026, 3, 3, 8, 0), endDate: date(2026, 3, 3, 9, 0), note: "C")
        try store.add(startDate: date(2026, 3, 2, 8, 0), endDate: date(2026, 3, 2, 9, 0), note: "B")

        #expect(store.entries.map(\.note) == ["C", "B", "A"])
    }

    @Test("A corrupt file loads as an empty store instead of failing")
    @MainActor
    func corruptFile() throws {
        let directory = try TemporaryDirectory()
        let fileURL = directory.url.appendingPathComponent("entries.json")
        try Data("{ not json at all".utf8).write(to: fileURL)

        let store = EntryStore(directory: directory.url, calendar: utcCalendar)

        #expect(store.entries.isEmpty)

        // The store stays usable afterwards.
        try store.add(startDate: date(2026, 3, 1, 8, 0), endDate: date(2026, 3, 1, 9, 0), note: "New")
        #expect(store.entries.count == 1)

        let reloaded = EntryStore(directory: directory.url, calendar: utcCalendar)
        #expect(reloaded.entries.map(\.note) == ["New"])
    }

    @Test("An empty file loads as an empty store")
    @MainActor
    func emptyFile() throws {
        let directory = try TemporaryDirectory()
        try Data().write(to: directory.url.appendingPathComponent("entries.json"))

        let store = EntryStore(directory: directory.url, calendar: utcCalendar)

        #expect(store.entries.isEmpty)
    }

    @Test("A blank note is rejected and nothing is stored")
    @MainActor
    func blankNoteRejected() throws {
        let directory = try TemporaryDirectory()
        let store = EntryStore(directory: directory.url, calendar: utcCalendar)
        let start = date(2026, 3, 10, 9, 0)
        let end = date(2026, 3, 10, 9, 30)

        #expect(throws: EntryStoreError.emptyNote) {
            try store.add(startDate: start, endDate: end, note: "")
        }
        #expect(throws: EntryStoreError.emptyNote) {
            try store.add(startDate: start, endDate: end, note: "  \n\t ")
        }

        #expect(store.entries.isEmpty)
        #expect(FileManager.default.fileExists(atPath: store.fileURL.path) == false)
    }

    @Test("Notes are trimmed on the way in")
    @MainActor
    func notesAreTrimmed() throws {
        let directory = try TemporaryDirectory()
        let store = EntryStore(directory: directory.url, calendar: utcCalendar)

        let stored = try store.add(
            startDate: date(2026, 3, 10, 9, 0),
            endDate: date(2026, 3, 10, 9, 30),
            note: "  Paired on the parser  "
        )

        #expect(stored.note == "Paired on the parser")
        #expect(store.entries.first?.note == "Paired on the parser")
    }

    @Test("Editing a note persists, and a blank edit is refused")
    @MainActor
    func updateNote() throws {
        let directory = try TemporaryDirectory()
        let store = EntryStore(directory: directory.url, calendar: utcCalendar)
        let entry = try store.add(
            startDate: date(2026, 3, 10, 9, 0),
            endDate: date(2026, 3, 10, 9, 30),
            note: "Original"
        )

        try store.updateNote("  Updated  ", for: entry.id)
        #expect(store.entry(with: entry.id)?.note == "Updated")

        #expect(throws: EntryStoreError.emptyNote) {
            try store.updateNote("   ", for: entry.id)
        }
        #expect(throws: EntryStoreError.entryNotFound) {
            try store.updateNote("Ghost", for: UUID())
        }
        #expect(store.entry(with: entry.id)?.note == "Updated")

        let reloaded = EntryStore(directory: directory.url, calendar: utcCalendar)
        #expect(reloaded.entries.map(\.note) == ["Updated"])
    }

    @Test("Deleting removes the entry from memory and from disk")
    @MainActor
    func deleteEntries() throws {
        let directory = try TemporaryDirectory()
        let store = EntryStore(directory: directory.url, calendar: utcCalendar)
        let keep = try store.add(
            startDate: date(2026, 3, 10, 9, 0),
            endDate: date(2026, 3, 10, 9, 30),
            note: "Keep"
        )
        let drop = try store.add(
            startDate: date(2026, 3, 11, 9, 0),
            endDate: date(2026, 3, 11, 9, 30),
            note: "Drop"
        )

        store.delete(drop.id)

        #expect(store.entries.map(\.id) == [keep.id])

        let reloaded = EntryStore(directory: directory.url, calendar: utcCalendar)
        #expect(reloaded.entries.map(\.note) == ["Keep"])

        // Deleting an unknown id is a no-op.
        store.delete(UUID())
        #expect(store.entries.count == 1)
    }

    @Test("Entries are bucketed per day, oldest first inside a day")
    @MainActor
    func dayBucketing() throws {
        let directory = try TemporaryDirectory()
        let store = EntryStore(directory: directory.url, calendar: utcCalendar)

        try store.add(
            startDate: date(2026, 3, 10, 9, 0),
            endDate: date(2026, 3, 10, 10, 0),
            note: "Morning"
        )
        try store.add(
            startDate: date(2026, 3, 10, 14, 0),
            endDate: date(2026, 3, 10, 14, 30),
            note: "Afternoon"
        )
        try store.add(
            startDate: date(2026, 3, 12, 11, 0),
            endDate: date(2026, 3, 12, 11, 15),
            note: "Other day"
        )

        let tenth = date(2026, 3, 10, 23, 59)
        #expect(store.entries(on: tenth).map(\.note) == ["Morning", "Afternoon"])
        #expect(store.totalDuration(on: tenth) == 5400)
        #expect(store.hasEntries(on: tenth))

        let eleventh = date(2026, 3, 11, 12, 0)
        #expect(store.entries(on: eleventh).isEmpty)
        #expect(store.totalDuration(on: eleventh) == 0)
        #expect(store.hasEntries(on: eleventh) == false)
    }

    @Test("Marked days cover only the visible month")
    @MainActor
    func daysWithEntriesForMonth() throws {
        let directory = try TemporaryDirectory()
        let store = EntryStore(directory: directory.url, calendar: utcCalendar)

        try store.add(
            startDate: date(2026, 3, 10, 9, 0),
            endDate: date(2026, 3, 10, 10, 0),
            note: "March 10 a"
        )
        try store.add(
            startDate: date(2026, 3, 10, 16, 0),
            endDate: date(2026, 3, 10, 17, 0),
            note: "March 10 b"
        )
        try store.add(
            startDate: date(2026, 3, 31, 9, 0),
            endDate: date(2026, 3, 31, 9, 30),
            note: "March 31"
        )
        try store.add(
            startDate: date(2026, 4, 1, 9, 0),
            endDate: date(2026, 4, 1, 9, 30),
            note: "April 1"
        )

        let marchDays = store.daysWithEntries(in: date(2026, 3, 15, 12, 0))

        #expect(marchDays.count == 2)
        #expect(marchDays.contains(utcCalendar.startOfDay(for: date(2026, 3, 10, 9, 0))))
        #expect(marchDays.contains(utcCalendar.startOfDay(for: date(2026, 3, 31, 9, 0))))
        #expect(marchDays.contains(utcCalendar.startOfDay(for: date(2026, 4, 1, 9, 0))) == false)

        let aprilDays = store.daysWithEntries(in: date(2026, 4, 20, 12, 0))
        #expect(aprilDays == [utcCalendar.startOfDay(for: date(2026, 4, 1, 9, 0))])
    }

    @Test("An end date before the start date collapses to a zero-length entry")
    @MainActor
    func negativeRangeClamps() throws {
        let directory = try TemporaryDirectory()
        let store = EntryStore(directory: directory.url, calendar: utcCalendar)

        let stored = try store.add(
            startDate: date(2026, 3, 10, 10, 0),
            endDate: date(2026, 3, 10, 9, 0),
            note: "Clock skew"
        )

        #expect(stored.duration == 0)
    }
}

/// Serialized: these tests mutate a process-wide environment variable.
@Suite("EntryStore default directory", .serialized)
struct EntryStoreDirectoryTests {
    @Test("TIMETRACKER_DATA_DIR overrides Application Support")
    func environmentOverride() throws {
        let directory = try TemporaryDirectory()
        setenv("TIMETRACKER_DATA_DIR", directory.url.path, 1)
        defer { unsetenv("TIMETRACKER_DATA_DIR") }

        #expect(EntryStore.defaultDirectory().path == directory.url.path)
    }

    @Test("Without the override the store lives in Application Support/TimeTracker")
    func applicationSupportFallback() {
        unsetenv("TIMETRACKER_DATA_DIR")

        #expect(EntryStore.defaultDirectory().lastPathComponent == "TimeTracker")
    }
}
