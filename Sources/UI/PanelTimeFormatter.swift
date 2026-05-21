import Foundation

struct PanelTimeFormatter {
    private static func outputFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    private static func isoFormatter(formatOptions: ISO8601DateFormatter.Options) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = formatOptions
        return formatter
    }

    static func format(date: Date, timeZone: TimeZone) -> String {
        outputFormatter(timeZone: timeZone).string(from: date)
    }

    static func format(isoString: String, timeZone: TimeZone) -> String {
        let date =
            isoFormatter(formatOptions: [.withInternetDateTime, .withFractionalSeconds]).date(from: isoString)
            ?? isoFormatter(formatOptions: [.withInternetDateTime]).date(from: isoString)
        guard let date else { return isoString }
        return format(date: date, timeZone: timeZone)
    }

    static func relativeFutureText(isoString: String, timeZone: TimeZone, now: Date = Date()) -> String {
        let date =
            isoFormatter(formatOptions: [.withInternetDateTime, .withFractionalSeconds]).date(from: isoString)
            ?? isoFormatter(formatOptions: [.withInternetDateTime]).date(from: isoString)
        guard let date else { return isoString }

        let remaining = Int(date.timeIntervalSince(now))
        guard remaining > 0, remaining < 24 * 60 * 60 else {
            return format(date: date, timeZone: timeZone)
        }

        let minutes = max(1, Int(ceil(Double(remaining) / 60.0)))
        if minutes < 60 { return "in \(minutes) \(unit("minute", count: minutes))" }

        let hours = minutes / 60
        let remainderMinutes = minutes % 60
        if hours < 12, remainderMinutes > 0 {
            return "in \(hours) \(unit("hour", count: hours)) \(remainderMinutes) \(unit("minute", count: remainderMinutes))"
        }

        return "in \(hours) \(unit("hour", count: hours))"
    }

    private static func unit(_ singular: String, count: Int) -> String {
        count == 1 ? singular : "\(singular)s"
    }

    static func relativeUpdatedText(since date: Date, now: Date = Date()) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(date)))
        if elapsed < 60 { return "Updated \(elapsed) seconds ago" }
        let minutes = elapsed / 60
        if minutes < 60 { return "Updated \(minutes) minutes ago" }
        let hours = minutes / 60
        if hours < 24 { return "Updated \(hours) hours ago" }
        let days = hours / 24
        return "Updated \(days) days ago"
    }
}
