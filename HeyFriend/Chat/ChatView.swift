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
                VStack(spacing: 10) {
                    MicControl(isRecording: viewModel.isRecording) {
                        viewModel.toggleRecording()
                    }

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

    var body: some View {
        Button(action: {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            ZStack {
                // Subtle ring
                Circle()
                    .strokeBorder(.quaternary, lineWidth: 8)
                    .frame(width: 132, height: 132)
                    .scaleEffect(isRecording ? (pulse ? 1.06 : 1.0) : 1.0)
                    .animation(isRecording
                               ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                               : .default,
                               value: pulse)

                // Core
                Circle()
                    .fill(.thinMaterial)
                    .frame(width: 112, height: 112)
                    .overlay(
                        Circle().strokeBorder(.quaternary, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .onAppear { pulse = true }
        .accessibilityLabel(isRecording ? "Stop listening" : "Start listening")
        .accessibilityAddTraits(.isButton)
    }
}
