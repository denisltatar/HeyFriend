//
//  HeyFriendApp.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/8/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
      
    if let app = FirebaseApp.app() {
        let opt = app.options
        print("Firebase projectID:", opt.projectID ?? "nil")
        print("Firebase API key:", opt.apiKey ?? "nil")
        print("Detected bundleID:", Bundle.main.bundleIdentifier ?? "nil")
        print("\n")
    }
      
    // List ALL Google plists bundled (to catch duplicates / wrong target)
    let paths = Bundle.main.paths(forResourcesOfType: "plist", inDirectory: nil)
        .filter { $0.hasSuffix("GoogleService-Info.plist") }
    print("Google plists in app bundle:", paths)
    print("\n")

    return true
  }
}

//class AppDelegate: NSObject, UIApplicationDelegate {
//  func application(_ application: UIApplication,
//                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
//    FirebaseApp.configure()
//    return true
//  }
//}

@main
struct HeyFriendApp: App {
    // Initilizing Firebase for HeyFriend
//    init() {
//        FirebaseApp.configure()
//    }
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
