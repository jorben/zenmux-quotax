import Foundation
import Combine

public enum StatusBarQuotaDisplayMode: String, CaseIterable, Identifiable {
    case used
    case left

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .used: return "Used percentage"
        case .left: return "Left percentage"
        }
    }
}

public enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

public enum StatusBarDataColorMode: String, CaseIterable, Identifiable {
    case auto
    case light = "white"
    case dark = "black"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

public enum StatusBarPresentationStyle: String, CaseIterable, Identifiable {
    case labelsAndPercentage
    case iconAndPercentage
    case doubleRingAndPercentage
    case doubleBarAndPercentage
    case doubleRing
    case doubleBar
    case percentageOnly
    case iconOnly

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .labelsAndPercentage: return "Labels + %"
        case .iconAndPercentage: return "Icon + %"
        case .doubleRingAndPercentage: return "Double ring + %"
        case .doubleBarAndPercentage: return "Bars + %"
        case .doubleRing: return "Double ring"
        case .doubleBar: return "Bars"
        case .percentageOnly: return "% only"
        case .iconOnly: return "Icon only"
        }
    }
}

public enum ProxyMode: String, CaseIterable, Identifiable, Sendable {
    case none
    case system
    case manual

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return "None"
        case .system: return "System"
        case .manual: return "Manual"
        }
    }
}

public enum ProxyType: String, CaseIterable, Identifiable, Sendable {
    case http
    case https
    case socks5

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .http: return "HTTP"
        case .https: return "HTTPS"
        case .socks5: return "SOCKS5"
        }
    }
}

public struct ProxyConfiguration: Sendable {
    public let mode: ProxyMode
    public let type: ProxyType?
    public let host: String?
    public let port: Int?
    public let username: String?
    public let password: String?

    public static func isEqual(_ lhs: ProxyConfiguration?, _ rhs: ProxyConfiguration?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): return true
        case (.some(let lhs), .some(let rhs)):
            return lhs.mode == rhs.mode
                && lhs.type == rhs.type
                && lhs.host == rhs.host
                && lhs.port == rhs.port
                && lhs.username == rhs.username
                && lhs.password == rhs.password
        default: return false
        }
    }
}

@MainActor
public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    private enum Keys {
        static let apiKey = "api_key"
        static let refreshInterval = "refresh_interval"
        static let alwaysRefresh = "alwaysRefresh"
        static let statusBarQuotaDisplayMode = "statusBarQuotaDisplayMode"
        static let statusBarDataColorMode = "statusBarDataColorMode"
        static let statusBarPresentationStyle = "statusBarPresentationStyle"
        static let appearanceMode = "appearanceMode"
        static let timeZoneIdentifier = "timeZoneIdentifier"
        static let launchAtLogin = "launchAtLogin"
        static let logMinimumLevel = "logMinimumLevel"
        static let proxyMode = "proxy_mode"
        static let proxyType = "proxy_type"
        static let proxyHost = "proxy_host"
        static let proxyPort = "proxy_port"
        static let proxyUsername = "proxy_username"
        static let proxyPassword = "proxy_password"
    }

    public static let utcOffsetOptions: [Int] = Array(-12...14)

    public static func utcOffsetTitle(_ hours: Int) -> String {
        if hours == 0 { return "UTC" }
        let sign = hours > 0 ? "+" : ""
        return "UTC\(sign)\(hours)"
    }

    public static func utcOffsetIdentifier(_ hours: Int) -> String {
        "UTC\(hours >= 0 ? "+" : "")\(hours)"
    }

    public static func parseUTCOffsetHours(_ identifier: String) -> Int? {
        guard identifier.hasPrefix("UTC") else { return nil }
        return Int(identifier.dropFirst(3))
    }

    private let defaults: UserDefaults
    private let launchAtLoginService: LaunchAtLoginService

    @Published public var apiKey: String {
        didSet { defaults.set(apiKey, forKey: Keys.apiKey) }
    }

    @Published public var refreshInterval: TimeInterval {
        didSet { defaults.set(refreshInterval, forKey: Keys.refreshInterval) }
    }

    @Published public var alwaysRefresh: Bool {
        didSet { defaults.set(alwaysRefresh, forKey: Keys.alwaysRefresh) }
    }

    @Published public var statusBarQuotaDisplayMode: StatusBarQuotaDisplayMode {
        didSet { defaults.set(statusBarQuotaDisplayMode.rawValue, forKey: Keys.statusBarQuotaDisplayMode) }
    }

    @Published public var statusBarDataColorMode: StatusBarDataColorMode {
        didSet { defaults.set(statusBarDataColorMode.rawValue, forKey: Keys.statusBarDataColorMode) }
    }

    @Published public var statusBarPresentationStyle: StatusBarPresentationStyle {
        didSet { defaults.set(statusBarPresentationStyle.rawValue, forKey: Keys.statusBarPresentationStyle) }
    }

    @Published public var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }

    @Published public var timeZoneIdentifier: String {
        didSet { defaults.set(timeZoneIdentifier, forKey: Keys.timeZoneIdentifier) }
    }

    @Published public var launchAtLogin: Bool {
        didSet {
            guard !isApplyingLaunchAtLoginRollback else { return }
            setLaunchAtLogin(launchAtLogin)
        }
    }

    @Published public var logMinimumLevel: AppLogLevel {
        didSet {
            defaults.set(logMinimumLevel.rawValueString, forKey: Keys.logMinimumLevel)
            AppLog.setMinimumLevel(logMinimumLevel)
        }
    }

    @Published public var proxyMode: ProxyMode {
        didSet { defaults.set(proxyMode.rawValue, forKey: Keys.proxyMode) }
    }

    @Published public var proxyType: ProxyType {
        didSet { defaults.set(proxyType.rawValue, forKey: Keys.proxyType) }
    }

    @Published public var proxyHost: String {
        didSet { defaults.set(proxyHost, forKey: Keys.proxyHost) }
    }

    @Published public var proxyPort: Int {
        didSet { defaults.set(proxyPort, forKey: Keys.proxyPort) }
    }

    @Published public var proxyUsername: String {
        didSet { defaults.set(proxyUsername, forKey: Keys.proxyUsername) }
    }

    @Published public var proxyPassword: String {
        didSet { defaults.set(proxyPassword, forKey: Keys.proxyPassword) }
    }

    @Published public private(set) var launchAtLoginError: String?
    private var isApplyingLaunchAtLoginRollback = false

    public init(defaults: UserDefaults = .standard, launchAtLoginService: LaunchAtLoginService = LaunchAtLoginService()) {
        self.defaults = defaults
        self.launchAtLoginService = launchAtLoginService
        self.apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
        let storedInterval = defaults.double(forKey: Keys.refreshInterval)
        self.refreshInterval = storedInterval > 0 ? storedInterval : AppConstants.Refresh.defaultInterval
        self.alwaysRefresh = defaults.object(forKey: Keys.alwaysRefresh) as? Bool ?? true
        let storedDisplayMode = defaults.string(forKey: Keys.statusBarQuotaDisplayMode) ?? StatusBarQuotaDisplayMode.used.rawValue
        self.statusBarQuotaDisplayMode = StatusBarQuotaDisplayMode(rawValue: storedDisplayMode) ?? .used
        let storedStatusBarDataColorMode = defaults.string(forKey: Keys.statusBarDataColorMode) ?? StatusBarDataColorMode.auto.rawValue
        self.statusBarDataColorMode = StatusBarDataColorMode(rawValue: storedStatusBarDataColorMode) ?? .auto
        let storedPresentationStyle = defaults.string(forKey: Keys.statusBarPresentationStyle) ?? StatusBarPresentationStyle.labelsAndPercentage.rawValue
        self.statusBarPresentationStyle = StatusBarPresentationStyle(rawValue: storedPresentationStyle) ?? .labelsAndPercentage
        let storedAppearanceMode = defaults.string(forKey: Keys.appearanceMode) ?? AppearanceMode.system.rawValue
        self.appearanceMode = AppearanceMode(rawValue: storedAppearanceMode) ?? .system
        let storedTimeZone = defaults.string(forKey: Keys.timeZoneIdentifier) ?? TimeZone.current.identifier
        let resolved = Self.resolveTimeZoneIdentifier(storedTimeZone)
        self.timeZoneIdentifier = resolved
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        let storedLogMinimumLevel = defaults.string(forKey: Keys.logMinimumLevel) ?? AppLogLevel.info.rawValueString
        self.logMinimumLevel = AppLogLevel(storedValue: storedLogMinimumLevel) ?? .info
        let storedProxyMode = defaults.string(forKey: Keys.proxyMode) ?? ProxyMode.none.rawValue
        self.proxyMode = ProxyMode(rawValue: storedProxyMode) ?? .none
        let storedProxyType = defaults.string(forKey: Keys.proxyType) ?? ProxyType.http.rawValue
        self.proxyType = ProxyType(rawValue: storedProxyType) ?? .http
        self.proxyHost = defaults.string(forKey: Keys.proxyHost) ?? ""
        self.proxyPort = defaults.integer(forKey: Keys.proxyPort)
        self.proxyUsername = defaults.string(forKey: Keys.proxyUsername) ?? ""
        self.proxyPassword = defaults.string(forKey: Keys.proxyPassword) ?? ""
        self.launchAtLoginError = nil
        AppLog.setMinimumLevel(logMinimumLevel)
    }

    public var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var timeZone: TimeZone {
        if let hours = Self.parseUTCOffsetHours(timeZoneIdentifier) {
            return TimeZone(secondsFromGMT: hours * 3600) ?? .current
        }
        return .current
    }

    public static func resolveTimeZoneIdentifier(_ identifier: String) -> String {
        if let hours = parseUTCOffsetHours(identifier), utcOffsetOptions.contains(hours) {
            return utcOffsetIdentifier(hours)
        }
        let currentOffset = TimeZone(identifier: identifier)?.secondsFromGMT()
            ?? TimeZone.current.secondsFromGMT()
        let hoursOffset = Int(round(Double(currentOffset) / 3600.0))
        let clamped = max(-12, min(14, hoursOffset))
        return utcOffsetIdentifier(clamped)
    }

    public var proxyConfiguration: ProxyConfiguration? {
        guard proxyMode != .none else { return nil }
        if proxyMode == .manual {
            let host = proxyHost.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !host.isEmpty, (1...65535).contains(proxyPort) else { return nil }
            return ProxyConfiguration(
                mode: proxyMode,
                type: proxyType,
                host: host,
                port: proxyPort,
                username: proxyUsername.trimmingCharacters(in: .whitespacesAndNewlines),
                password: proxyPassword
            )
        }
        return ProxyConfiguration(mode: proxyMode, type: nil, host: nil, port: nil, username: nil, password: nil)
    }

    public func refreshLaunchAtLoginStatus() {
        applyLaunchAtLoginStatus(launchAtLoginService.isEnabled, clearError: true)
    }

    private func applyLaunchAtLoginStatus(_ systemEnabled: Bool, clearError: Bool) {
        isApplyingLaunchAtLoginRollback = true
        launchAtLogin = systemEnabled
        isApplyingLaunchAtLoginRollback = false
        defaults.set(systemEnabled, forKey: Keys.launchAtLogin)
        if clearError {
            launchAtLoginError = nil
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            applyLaunchAtLoginStatus(launchAtLoginService.isEnabled, clearError: true)
        } catch {
            launchAtLoginError = error.localizedDescription
            applyLaunchAtLoginStatus(launchAtLoginService.isEnabled, clearError: false)
        }
    }
}
