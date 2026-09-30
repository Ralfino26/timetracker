import SwiftUI
import TimetrackerCore

/// Month grid with a dot under every day that has entries.
struct MonthCalendarView: View {
    @EnvironmentObject private var store: EntryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var month: Date
    @Binding var selectedDay: Date

    private let calendar = Calendar.current

    private var monthChange: Animation? { reduceMotion ? nil : .snappy(duration: 0.22) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            monthHeader
            weekdayHeader
            grid
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var monthHeader: some View {
        HStack(spacing: 6) {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .contentTransition(.numericText())

            Spacer(minLength: 0)

            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .help("Previous month")

            Button {
                goToToday()
            } label: {
                Text("Today")
            }
            .help("Jump to today")

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .help("Next month")
        }
        .buttonStyle(.accessoryBar)
        .animation(monthChange, value: month)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let marked = store.daysWithEntries(in: month)

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day, hasEntries: marked.contains(calendar.startOfDay(for: day)))
                } else {
                    Color.clear.frame(height: 34)
                }
            }
        }
        .animation(monthChange, value: month)
    }

    private func dayCell(_ day: Date, hasEntries: Bool) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)

        return Button {
            withAnimation(reduceMotion ? nil : .bouncy(duration: 0.28)) {
                selectedDay = calendar.startOfDay(for: day)
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .monospacedDigit()

                Circle()
                    .frame(width: 4, height: 4)
                    .opacity(hasEntries ? 1 : 0)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background {
                if isSelected {
                    Circle()
                        .fill(.tint)
                        .frame(width: 30, height: 30)
                } else if isToday {
                    Circle()
                        .strokeBorder(.tint, lineWidth: 1)
                        .frame(width: 30, height: 30)
                }
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Days of the visible month, padded with `nil` so week rows line up.
    private var monthDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let dayRange = calendar.range(of: .day, in: .month, for: month)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayRange.count {
            days.append(calendar.date(byAdding: .day, value: offset, to: interval.start))
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        guard shift > 0, shift < symbols.count else { return symbols }
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private func shiftMonth(by value: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: value, to: month) else { return }
        withAnimation(monthChange) { month = shifted }
    }

    private func goToToday() {
        let today = calendar.startOfDay(for: Date())
        withAnimation(monthChange) {
            month = today
            selectedDay = today
        }
    }
}
