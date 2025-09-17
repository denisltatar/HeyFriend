//
//  CountdownBanner.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/17/25.
//

import Foundation
import SwiftUI

struct CountdownBanner: View {
    let secondsRemaining: Int   // pass 300 at 25-min mark, live seconds <=60 later

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.headline.weight(.semibold))
            if secondsRemaining > 60 {
                Text("You’ve got ~5 minutes left in this session.")
                    .font(.subheadline).fontWeight(.semibold)
            } else {
                Text("Session ends in \(secondsRemaining)s")
                    .font(.subheadline).fontWeight(.bold)
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.08)))
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: secondsRemaining)
    }
}
