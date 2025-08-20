//
//  InsightsView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/19/25.
//

import Foundation

// InsightsView.swift  (You can place under a new folder: HeyFriend/Insights/)
import SwiftUI

struct InsightsView: View {
    var body: some View {
        List {
            Section("This Week at a Glance") {
                Text("Mood trend and top emotion will appear here.")
            }
            Section("Recent Summaries") {
                Text("Your saved summaries will appear here.")
            }
        }
    }
}

