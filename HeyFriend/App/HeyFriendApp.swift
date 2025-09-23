//
//  HeyFriendApp.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/8/25.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
      func application(_ application: UIApplication,
                       didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
          
        // ✅ Tell GoogleSignIn what clientID to use (from Firebase options)
        if let clientID = FirebaseApp.app()?.options.clientID {
          GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
          print("GID clientID set ✅:", clientID)
        } else {
          assertionFailure("Missing Firebase clientID")
        }
          
        if let app = FirebaseApp.app() {
            let opt = app.options
            print("Firebase projectID:", opt.projectID ?? "nil")
//            print("Firebase API key:", opt.apiKey ?? "nil")
            print("Detected bundleID:", Bundle.main.bundleIdentifier ?? "nil")
            print("\n")
        }
      
    // sanity check for multiple Google plists
        let paths = Bundle.main.paths(forResourcesOfType: "plist", inDirectory: nil)
            .filter { $0.hasSuffix("GoogleService-Info.plist") }
        print("Google plists in app bundle:", paths)
        print("\n")

        return true
      }
    
    // ✅ Required for Google Sign-In to complete the OAuth flow
      func application(_ app: UIApplication,
                       open url: URL,
                       options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
      }
}


@main
struct HeyFriendApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    // inject auth & route
    @StateObject private var auth = AuthService.shared
    
    // Applying color theme
    @AppStorage(SettingsKeys.appAppearance) private var appearanceRaw = AppAppearance.system.rawValue

    // ⬇️ Added this to refresh when app becomes active
    @Environment(\.scenePhase) private var scenePhase
    @State private var authHandle: AuthStateDidChangeListenerHandle?
    
    var body: some Scene {
        let appearance = AppAppearance(rawValue: appearanceRaw) ?? AppAppearance.system
        
        WindowGroup {
            Group {
                if let user = Auth.auth().currentUser, !user.isAnonymous {
                    RootTabView().preferredColorScheme(appearance.colorScheme)
                } else {
                    WelcomeView().preferredColorScheme(appearance.colorScheme)
                }
            }.environmentObject(auth)
            
            // 👇 First ensure there is a user (anon if needed), THEN start entitlement sync
//            .task {
//                if AuthService.shared.userId == nil {
//                    try? await AuthService.shared.signInAnonymouslyIfNeeded()
//                }
//                EntitlementSync.shared.start()
//                await EntitlementSync.shared.refresh()
//            }
            
            .task {
                authHandle = Auth.auth().addStateDidChangeListener { _, user in
                    if let user, !user.isAnonymous {
                        print("👤 Signed in as:", user.uid)
                        EntitlementSync.shared.start()
                        Task { await EntitlementSync.shared.refresh() }
                    } else {
                        print("👤 Signed out (or anonymous) — clearing local Plus flag")
                        EntitlementSync.shared.clearLocalFlagOnLogout()
                    }
                }
            }


           // ⬇️ ADDED: refresh when app returns to foreground
           .onChange(of: scenePhase) { phase in
               if phase == .active, let u = Auth.auth().currentUser, !u.isAnonymous {
                   Task { await EntitlementSync.shared.refresh() }
               }
           }
        }
    } 
}
