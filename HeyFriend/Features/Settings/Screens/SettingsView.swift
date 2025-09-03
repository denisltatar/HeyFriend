//
//  SettingsView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/19/25.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    
    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("Require Face ID for Insights", isOn: .constant(false))
                Toggle("Back up summariesgit  to iCloud", isOn: .constant(false))
            }
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button(role: .destructive) {
                    auth.signOut()
                } label: {
                    Text("Sign Out")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
}
