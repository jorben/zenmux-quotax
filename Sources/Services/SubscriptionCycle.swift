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

enum ZenmuxSubscriptionCycle {
    private enum Interval {
        case day
        case week
        case month
        case year

        init?(rawValue: String?) {
            guard let rawValue else { return nil }
            switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "day", "daily": self = .day
            case "week", "weekly": self = .week
            case "month", "monthly": self = .month
            case "year", "yearly", "annual": self = .year
            default: return nil
            }
        }

        var component: Calendar.Component {
            switch self {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            case .year: return .year
            }
        }
    }

    static func currentStatisticsRange(
        from subscriptionData: ZenmuxSubscriptionData?,
        now: Date = Date()
    ) -> ZenmuxStatisticsDateRange? {
        guard
            let plan = subscriptionData?.plan,
            let expiresAt = plan.expiresAt,
            let expirationDate = parseISODate(expiresAt),
            let interval = Interval(rawValue: plan.interval),
            expirationDate > now
        else {
            return nil
        }

        let calendar = utcCalendar
        var cycleEnd = expirationDate
        guard let initialCycleStart = calendar.date(byAdding: interval.component, value: -1, to: cycleEnd) else {
            return nil
        }
        var cycleStart = initialCycleStart

        while now < cycleStart {
            cycleEnd = cycleStart
            guard let previousCycleStart = calendar.date(byAdding: interval.component, value: -1, to: cycleEnd) else {
                return nil
            }
            cycleStart = previousCycleStart
        }

        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }

        let firstAvailableDay = calendar.startOfDay(for: cycleStart)
        let lastCycleDay = calendar.startOfDay(for: cycleEnd)
        let lastAvailableDay = min(yesterday, lastCycleDay)
        guard firstAvailableDay <= lastAvailableDay else { return nil }

        return ZenmuxStatisticsDateRange(start: firstAvailableDay, end: lastAvailableDay)
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private static func parseISODate(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) { return date }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) { return date }

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.calendar = utcCalendar
        dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateOnlyFormatter.timeZone = utcCalendar.timeZone
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        return dateOnlyFormatter.date(from: value)
    }
}
