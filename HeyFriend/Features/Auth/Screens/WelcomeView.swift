//
//  WelcomeView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/2/25.
//

import SwiftUI

struct WelcomeView: View {
    @State private var isSigningIn = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            // Soft, warm background to match your orange theme
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.25),
                    Color(red: 1.0, green: 0.75, blue: 0.45).opacity(0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Optional: your orb/glow, very faint for depth
            VStack {
                Spacer()
                // If you want a subtle moving background, uncomment one line below:
                // OrbView(configuration: .init.presetWarmSunset) // if you have a preset
                // RotatingGlowView() // super soft glow behind the card
                Spacer()
            }
            .allowsHitTesting(false)

            // Content card
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 10) {
                    Text("HeyFriend")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Welcome back — let’s get you signed in.")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                // Card
                VStack(spacing: 16) {
                    GoogleSignInButton(isLoading: isSigningIn) {
                        signInWithGoogleTapped()
                    }

                    // Placeholder for Apple (later)
                    Button {
                        // TODO: Apple Sign-In later
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .bold))
                            Text("Sign in with Apple")
                                .font(.system(size: 17, weight: .semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .opacity(0.35) // disabled look for now
                    }
                    .disabled(true)

                    if let errorText {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }

                    Text("By continuing, you agree to our Terms & Privacy Policy.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 12)

                Spacer()
            }
            .padding(.vertical, 24)
        }
    }

    private func signInWithGoogleTapped() {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorText = nil

        Task {
            do {
                let presenter = RootPresenterFinder.topMostController()
                try await AuthService.shared.signInWithGoogle(presenting: presenter)
                // Success will flow you into RootTabView once you toggle in App entry (see Step 4 notes).
            } catch {
                errorText = error.localizedDescription
            }
            isSigningIn = false
        }
    }
}

#Preview {
    WelcomeView()
}
