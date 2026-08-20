import Foundation

struct ZenmuxStatisticsDateRange: Sendable {
    let start: Date
    let end: Date

    var startingAt: String {
        Self.apiDateString(from: start)
    }

    var endingAt: String {
        Self.apiDateString(from: end)
    }

    var dayCount: Int {
        let calendar = Self.utcCalendar
        guard let days = calendar.dateComponents([.day], from: start, to: end).day else { return 0 }
        return days + 1
    }

    static func recentDays(_ count: Int, now: Date = Date()) -> ZenmuxStatisticsDateRange? {
        guard count > 0 else { return nil }

        let calendar = Self.utcCalendar
        let end = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(count - 1), to: end) else {
            return nil
        }
        return Self(start: start, end: end)
    }

    func chunks(maxBucketCount: Int) -> [ZenmuxStatisticsDateRange] {
        guard maxBucketCount > 0, start <= end else { return [] }

        let calendar = Self.utcCalendar
        var ranges: [ZenmuxStatisticsDateRange] = []
        var chunkStart = start

        while chunkStart <= end {
            guard let candidateEnd = calendar.date(byAdding: .day, value: maxBucketCount - 1, to: chunkStart) else {
                break
            }
            let chunkEnd = min(candidateEnd, end)
            ranges.append(Self.init(start: chunkStart, end: chunkEnd))

            guard let nextStart = calendar.date(byAdding: .day, value: 1, to: chunkEnd), nextStart > chunkStart else {
                break
            }
            chunkStart = nextStart
        }

        return ranges
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private static func apiDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = utcCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = utcCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
