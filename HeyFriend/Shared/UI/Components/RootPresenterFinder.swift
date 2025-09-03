//
//  RootPresenterFinder.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/2/25.
//

import UIKit

enum RootPresenterFinder {
    static func topMostController(base: UIViewController? = {
        // start at the active window’s root
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        return scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    }()) -> UIViewController {
        if let nav = base as? UINavigationController {
            return topMostController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController,
           let selected = tab.selectedViewController {
            return topMostController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topMostController(base: presented)
        }
        return base ?? UIViewController()
    }
}
