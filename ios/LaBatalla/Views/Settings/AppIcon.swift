import UIKit

/// Keeps the home-screen icon on the one picked in Settings. iOS always shows a short
/// "You have changed the icon" notice when an app switches its own icon.
enum AppIcon {
    @MainActor static func match(_ choice: AppIconChoice) {
        let app = UIApplication.shared
        guard app.supportsAlternateIcons, app.alternateIconName != choice.iconName else { return }
        app.setAlternateIconName(choice.iconName) { _ in }
    }
}
