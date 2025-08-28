//
//  HeyFriendApp.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/8/25.
//

import SwiftUI
import UIKit
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct HeyFriendApp: App {
    // Initilizing Firebase for HeyFriend
//    init() {
//        FirebaseApp.configure()
//    }
    
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
