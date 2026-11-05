import Foundation

/// The version and build the app was built as (MARKETING_VERSION and CURRENT_PROJECT_VERSION
/// in the project), shown at the bottom of Settings. How the numbers move: ios/README.md.
enum AppVersion {
    static func label(version: String?, build: String?) -> String {
        var text = "La Batalla"
        if let version, !version.isEmpty { text += " \(version)" }
        if let build, !build.isEmpty { text += " - Build \(build)" }
        return text
    }

    static var current: String {
        let info = Bundle.main.infoDictionary
        return label(version: info?["CFBundleShortVersionString"] as? String,
                     build: info?["CFBundleVersion"] as? String)
    }
}
