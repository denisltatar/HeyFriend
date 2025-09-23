//
//  WelcomeView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/2/25.
//

import SwiftUI
import AuthenticationServices
import SafariServices

struct WelcomeView: View {
    @State private var isSigningIn = false
    @State private var errorText: String?
    @State private var showPrivacy = false

    var body: some View {
        ZStack {
            // Soft, warm background to match your orange theme
            LinearGradient(
                colors: [
//                    Color.orange.opacity(0.25),
//                    Color(red: 1.0, green: 0.75, blue: 0.45).opacity(0.25)
                    Color(red: 0.996, green: 0.804, blue: 0.373),
                    Color(red: 0.996, green: 0.486, blue: 0.0)
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
//                startPoint: .topLeading,
//                endPoint: .bottomTrailing
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
                    Image("AppLogo")   // <- replace "AppLogo" with the name in Assets.xcassets
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)    // adjust size as you like
                        .clipShape(RoundedRectangle(cornerRadius: 20)) // optional styling
                        .shadow(radius: 6)

                    Text("HeyFriend")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)

//                    Text("Welcome - let's get you signed in!")
//                        .font(.system(size: 17, weight: .regular))
//                        .foregroundStyle(Color.white.opacity(0.9))
//                        .multilineTextAlignment(.center)
//                        .padding(.horizontal, 24)
                    Text("Voice-first AI that helps you reflect-then surfaces gentle insights after each session.")
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

                    // ✅ Native Apple sign-in button
                    SignInWithAppleButton(.signIn) { request in
                        AuthService.shared.handleSignInWithAppleRequest(request)
                    } onCompletion: { result in
                        Task {
                            do {
                                try await AuthService.shared.handleSignInWithAppleCompletion(result)
                                // No manual navigation; app root will switch to RootTabView on auth change
                            } catch {
                                errorText = error.localizedDescription
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.black)   // auto inverts in Dark Mode if you prefer: use .white in dark
                    .frame(height: 52)
                    .cornerRadius(10)


                    if let errorText {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }

                    Text("By continuing, you agree to our [Terms & Privacy Policy](https://heyfriend-website.vercel.app/privacy).")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .foregroundStyle(.secondary) // gray for normal text
                        .tint(Color(red: 1.0, green: 0.55, blue: 0.0)) // 🍊 brand-orange link

                    
                    
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
    
    // Not currently used, although can be used in the near future
    struct SafariView: UIViewControllerRepresentable {
        let url: URL
        func makeUIViewController(context: Context) -> SFSafariViewController {
            SFSafariViewController(url: url)
        }
        func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
    }
}

#Preview {
    WelcomeView()
}
