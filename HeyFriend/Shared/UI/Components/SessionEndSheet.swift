//
//  SessionEndSheet.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/17/25.
//

import Foundation
import SwiftUI

struct SessionEndSheet: View {
    let onNew: () -> Void
    let onInsights: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass.bottomhalf.filled")
                .font(.system(size: 40, weight: .bold))
            Text("Time’s Up").font(.title2.bold())
            Text("Your Plus session hit the 30-minute limit. You can start a new one anytime.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("View Insights", action: onInsights).buttonStyle(.borderedProminent)
                Button("Start New Session", action: onNew).buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
