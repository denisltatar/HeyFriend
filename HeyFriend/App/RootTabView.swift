//
//  RootTabView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/19/25.
//

import Foundation
import SwiftUI

struct RootTabView: View {
    private let brandOrange = Color(red: 1.0, green: 0.478, blue: 0.0) // #FF7A00

    init() {
        let tabBar = UITabBar.appearance()
        tabBar.itemPositioning = .centered
        tabBar.itemSpacing = 12
        tabBar.itemWidth = 80
    }

    var body: some View {
        TabView {
            // Sessions
            NavigationStack { SessionsHomeView() }
                .tabItem {
                    Image(systemName: "bolt.house")
                        .font(.system(size: 18)) // shrink icon only
                    Text("Sessions")
                }

            // Insights
            NavigationStack { InsightsView().navigationTitle("Insights") }
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 18))
                    Text("Insights")
                }

            // Settings
            NavigationStack { SettingsView().navigationTitle("Settings") }
                .tabItem {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                    Text("Settings")
                }
        }
        // Changed across entire app!
        .tint(brandOrange)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}




// do async auth + hello write once when the view appears
//        .task {
//            #if DEBUG
//            do {
//                try await AuthService.shared.signInAnonymouslyIfNeeded()
//                if let uid = AuthService.shared.userId {
//                    print("Anon auth OK for DEBUG, uid:", uid)
//                }
//            } catch {
//                print("Anon auth error:", error)
//            }
//            #endif
//        }
