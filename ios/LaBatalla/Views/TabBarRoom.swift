import SwiftUI
import UIKit

/// The room every page keeps under the floating bar, so its last row, button or card can always
/// scroll up clear of the bar and of the Today tile standing out of it.
enum TabBarRoom {
    /// Between the last thing on a page and the top of the Today tile.
    static let clearance: CGFloat = 12

    /// How far the bar's bottom edge sits above the screen's. With a home indicator it floats a
    /// little into that space, like the system's bar; with a Home button it sits just off the edge.
    static func lift(device bottom: CGFloat) -> CGFloat { bottom > 0 ? bottom - 13 : 8 }

    /// Where pages stop, measured up from the bottom of the screen.
    static func pageBottom(device bottom: CGFloat) -> CGFloat {
        lift(device: bottom) + BattleTabBar.height + TodayTile.rise + clearance
    }

    /// What the bar adds to the phone's own bottom safe area.
    static func room(device bottom: CGFloat) -> CGFloat { max(0, pageBottom(device: bottom) - bottom) }
}

/// Puts the bar's room into the safe area at the root of the window, where UIKit hands it down to
/// every page under it: the SwiftUI ones, and the Lists and pushed pages inside each
/// NavigationStack. Sheets sit above the bar, so they never get the room.
/// Reports the phone's own bottom safe area, which the bar is placed by.
struct TabBarRoomSetter: UIViewRepresentable {
    @Binding var deviceBottom: CGFloat

    func makeUIView(context: Context) -> Probe {
        let v = Probe()
        v.isUserInteractionEnabled = false
        v.isAccessibilityElement = false
        return v
    }

    func updateUIView(_ v: Probe, context: Context) {
        v.report = { d in if deviceBottom != d { deviceBottom = d } }
        v.apply()
    }

    final class Probe: UIView {
        var report: ((CGFloat) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            apply()
        }

        func apply() {
            guard let window, let root = window.rootViewController else { return }
            // The window's own inset is the phone's; the room added below doesn't change it.
            let device = window.safeAreaInsets.bottom
            let room = TabBarRoom.room(device: device)
            if root.additionalSafeAreaInsets.bottom != room { root.additionalSafeAreaInsets.bottom = room }
            DispatchQueue.main.async { [report] in report?(device) }
        }
    }
}
