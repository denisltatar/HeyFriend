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
        TabView {
            // Sessions
            NavigationStack {
//                ChatView().navigationTitle("Sessions")
                ChatView()
            }
            .tabItem {
                Label("Sessions", systemImage: "bubble.left.and.bubble.right.fill")
            }

            // Insights
            NavigationStack {
                InsightsView().navigationTitle("Insights")
            }
            .tabItem {
                Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
            }

            // Settings
            NavigationStack {
                SettingsView().navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
    }
}
