import CoreGraphics
import Foundation

public enum AppConstants {
    public enum API {
        public static let zenmuxAIBaseURLString = "https://zenmux.ai"
        public static let zenmuxDevBaseURLString = "https://zenmux.dev"

        private static let subscriptionDetailPathComponents = ["api", "v1", "management", "subscription", "detail"]
        private static let managementPortalPathComponents = ["platform", "management"]

        public static func subscriptionDetailURL(baseURLString: String) -> URL? {
            url(baseURLString: baseURLString, pathComponents: subscriptionDetailPathComponents)
        }

        public static func managementPortalURL(baseURLString: String) -> URL? {
            url(baseURLString: baseURLString, pathComponents: managementPortalPathComponents)
        }

        private static func url(baseURLString: String, pathComponents: [String]) -> URL? {
            let trimmedBaseURLString = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard var components = URLComponents(string: trimmedBaseURLString),
                let scheme = components.scheme?.lowercased(),
                ["http", "https"].contains(scheme),
                components.host != nil
            else {
                return nil
            }

            components.query = nil
            components.fragment = nil
            guard let baseURL = components.url else { return nil }
            return pathComponents.reduce(baseURL) { url, pathComponent in
                url.appendingPathComponent(pathComponent)
            }
        }
    }

    public enum Network {
        public static let timeoutInterval: TimeInterval = 20
        public static let responseSnippetLimit = 512
    }

    public enum Refresh {
        public static let minimumInterval: TimeInterval = 30
        public static let defaultInterval: TimeInterval = 300

        public static func normalizedInterval(_ interval: TimeInterval) -> TimeInterval {
            guard interval.isFinite, interval >= minimumInterval else {
                return minimumInterval
            }
            return interval
        }
    }

    public enum Logging {
        public static let directoryName = "com.zenmux.quotax"
        public static let currentFileName = "quotax.log"
        public static let sessionStateFileName = "session-state.json"
        public static let maxFileSizeBytes: UInt64 = 5 * 1024 * 1024
        public static let maxArchivedFiles = 10
    }

    public enum StatusBar {
        public static let width: CGFloat = 72
    }

    public enum Menu {
        public static let width: CGFloat = 380
        public static let minimumHeight: CGFloat = 180
        public static let edgeInset: CGFloat = 8
        public static let verticalOffset: CGFloat = 6
        public static let fallbackTopOffset: CGFloat = 32
    }
}
