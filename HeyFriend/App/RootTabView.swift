//
//  RootTabView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/19/25.
//

import Foundation
import SwiftUI

struct RootTabView: View {
    var body: some View {
        ZStack {
            TabView {
                // Sessions
                NavigationStack {
                    //                ChatView().navigationTitle("Sessions")
                    //                ChatView()
                    SessionsHomeView()
                }
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                            .accessibilityLabel("Sessions")
                }
                
                // Insights
                NavigationStack {
                    InsightsView().navigationTitle("Insights")
                }
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .accessibilityLabel("Insights")
                }
                
                // Settings
                NavigationStack {
                    SettingsView().navigationTitle("Settings")
                }
                .tabItem {
                    Image(systemName: "gearshape.fill")
                        .accessibilityLabel("Settings")
                }
            }
        }// do async auth + hello write once when the view appears
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
    }
}
