//
//  GoogleSignInButton.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/2/25.
//

import SwiftUI

public struct GoogleSignInButton: View {
    var isLoading: Bool = false
    var action: () -> Void

    public init(isLoading: Bool = false,
                action: @escaping () -> Void) {
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: { if !isLoading { action() } }) {
            HStack(spacing: 12) {
                // G icon (24x24 asset from Google brand kit)
                Image("GoogleG")
                    .resizable()
                    .frame(width: 24, height: 24)

                Text("Continue with Google")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)

                Spacer(minLength: 0)

                if isLoading {
                    ProgressView().progressViewStyle(.circular)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(white: 0.85), lineWidth: 1)
            )
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        }
        .accessibilityLabel(Text("Continue with Google"))
    }
}
