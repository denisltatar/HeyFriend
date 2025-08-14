//
//  ChatView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/8/25.
//

import Foundation
import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            // Adaptive system background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            

            VStack(spacing: 12) {
                // Top bar
//                HStack {
//                    Spacer()
//                    Button { showingSettings = true } label: {
//                        Image(systemName: "gearshape.fill")
//                            .font(.system(size: 16, weight: .semibold, design: .rounded))
//                            .foregroundStyle(.secondary)
//                            .padding(10)
//                            .background(
//                                RoundedRectangle(cornerRadius: 12, style: .continuous)
//                                    .fill(.ultraThinMaterial)
//                            )
//                    }
//                    .buttonStyle(.plain)
//                    .accessibilityLabel("Settings")
//                }
//                .padding(.horizontal, 4)
                
//                LiquidSwirlOrbView(mode: .listening)
                LiquidSwirlOrbView(
                    mode: viewModel.isTTSSpeaking ? .responding : .listening,
                    size: 176 // keep it compact
                )


                // Conversation
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if !viewModel.transcribedText.isEmpty {
                            MessageCard(role: "You",
                                        text: viewModel.transcribedText,
                                        alignment: .trailing,
                                        tone: .user)
                        }

                        if !viewModel.aiResponse.isEmpty {
                            MessageCard(role: "Assistant",
                                        text: viewModel.aiResponse,
                                        alignment: .leading,
                                        tone: .ai)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 2)
                }

                // Mic control
                VStack(spacing: 13) {
                    MicControl(isRecording: viewModel.isRecording) {
                        viewModel.toggleRecording()
                    }.frame(width: 100, height: 100)

                    Text(viewModel.isRecording ? "Listening…" : "Tap to speak")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
                }
                .padding(.vertical, 8)
            }
            .padding(16)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                Form {
                    Section(header: Text("Playback")) {
                        // Wire to your model if needed
                        Toggle("Voice replies", isOn: .constant(true))
                    }
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// MARK: - Components

private struct MessageCard: View {
    enum Tone { case user, ai }

    let role: String
    let text: String
    let alignment: HorizontalAlignment
    let tone: Tone

    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(role)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)

            HStack(alignment: .bottom) {
                if alignment == .trailing { Spacer(minLength: 48) }

                Text(text)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(tone == .user ? .thinMaterial : .ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
                    .frame(maxWidth: 640, alignment: .leading)

                if alignment == .leading { Spacer(minLength: 48) }
            }
        }
        .padding(.horizontal, 2)
        .transition(.opacity.combined(with: .move(edge: alignment == .leading ? .leading : .trailing)))
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: text)
    }
}

private struct MicControl: View {
    let isRecording: Bool
    let action: () -> Void

    @State private var pulse = false

    // Brand-ish warm tones — tweak if you want
    private let amber  = Color(red: 1.00, green: 0.72, blue: 0.34)
    private let orange = Color(red: 1.00, green: 0.45, blue: 0.00)
    private let halo   = Color(red: 1.00, green: 0.65, blue: 0.20)

    var body: some View {
        Button(action: {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            ZStack {
                // Ambient ring (breathes only while recording)
                Circle()
                    .stroke(halo.opacity(isRecording ? 0.45 : 0.18), lineWidth: 8)
                    .frame(width: 100, height: 100)
                    .scaleEffect(isRecording ? (pulse ? 1.06 : 1.0) : 1.0)
                    .animation(isRecording
                               ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                               : .default,
                               value: pulse)
                    .shadow(color: halo.opacity(isRecording ? 0.35 : 0.18), radius: 14, x: 0, y: 8)

                // Core button with gradient fill
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [amber, orange]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                    .overlay(
                        Circle().stroke(amber.opacity(0.55), lineWidth: 1.5)
                    )
                    .shadow(color: halo.opacity(0.55), radius: 18, x: 0, y: 10)

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .onAppear { pulse = true }
        .accessibilityLabel(isRecording ? "Stop listening" : "Start listening")
        .accessibilityAddTraits(.isButton)
    }
}

