//
//  SettingsView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/19/25.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("Require Face ID for Insights", isOn: .constant(false))
                Toggle("Back up summaries to iCloud", isOn: .constant(false))
            }
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
