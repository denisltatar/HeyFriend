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
    @State private var smoothedSpeed: Double = 48
    @State private var lastSpokeAt: Date = .distantPast
    @State private var quantizedSpeed: Double = 48
    
    // Summaries
    @State private var showingSummary = false
    
    // Amplitude for orb to use to "breathe"
    private var orbAmplitude: CGFloat {
        let mic = viewModel.rmsLevel        // 0…1 from mic
        let tts = viewModel.ttsLevel        // 0…1 from AVAudioPlayer metering
        let speakingFloor: CGFloat = viewModel.isTTSSpeaking ? 0.10 : 0
        return max(mic, max(tts, speakingFloor))
    }

    private var targetSpeed: Double {
        let isSpeaking = viewModel.isTTSSpeaking
        let rawLevel = Double(min(max(viewModel.rmsLevel, 0), 1)) // 0…1 clamp

        // Only couple to level while speaking (or briefly after)
        let recentlySpeaking = Date().timeIntervalSince(lastSpokeAt) < 0.45
        let level = (isSpeaking || recentlySpeaking) ? rawLevel : 0.0

        // Calm bases + gentle coupling
        let base = isSpeaking ? 60.0 : 38.0
        let coupled = base * (1 + 0.12 * level)        // ↓ small voice influence

        // Hard clamp so it can’t explode
        return min(max(coupled, 24.0), 72.0)
    }

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
//                LiquidSwirlOrbView(
//                    mode: viewModel.isTTSSpeaking ? .responding : .listening,
//                    size: 176 // keep it compact
//                )
                OrbView(configuration: makeOrbConfig(speed: quantizedSpeed),
                        amplitude: orbAmplitude)
                    .frame(width: 176, height: 176)
                    .onAppear { smoothedSpeed = targetSpeed; quantizedSpeed = targetSpeed }
                    .onChange(of: targetSpeed) { new in
                        let alpha = 0.18
                        smoothedSpeed += (new - smoothedSpeed) * alpha
                        let step = 6.0
                        let stepped = (smoothedSpeed / step).rounded() * step
                        if abs(stepped - quantizedSpeed) >= 0.5 {
                            quantizedSpeed = stepped
                        }
                    }


                // Conversation
//                ScrollView(showsIndicators: false) {
//                    VStack(alignment: .leading, spacing: 12) {
//                        if !viewModel.transcribedText.isEmpty {
//                            MessageCard(role: "You",
//                                        text: viewModel.transcribedText,
//                                        alignment: .trailing,
//                                        tone: .user)
//                        }
//
//                        if !viewModel.aiResponse.isEmpty {
//                            MessageCard(role: "Assistant",
//                                        text: viewModel.aiResponse,
//                                        alignment: .leading,
//                                        tone: .ai)
//                        }
//                    }
//                    .padding(.top, 4)
//                    .padding(.horizontal, 2)
//                }
                
                Spacer()
                
                HStack {
                    Spacer()

                    ZStack(alignment: .trailing) {
                        VStack(spacing: 13) {
                            MicControl(isRecording: viewModel.isRecording) {
                                viewModel.toggleRecording()
                            }
                            .frame(width: 100, height: 100)

                            Text(viewModel.isRecording ? "Listening…" : "Tap to speak")
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(.secondary)
                                .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
                        }

                        // X button “floats” to the right of mic
                        Button {
                            if viewModel.isRecording { viewModel.toggleRecording() }
                            let sessionId = UUID().uuidString
                            viewModel.endSessionAndSummarize()
                            showingSummary = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(.secondarySystemBackground))
                                    .frame(width: 56, height: 56)
                                    .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.gray)
                            }
                        }
                        .offset(x: 80, y: -5) // tweak these numbers for position
                    }

                    Spacer()
                }




                // Mic control
//                VStack(spacing: 13) {
//                    MicControl(isRecording: viewModel.isRecording) {
//                        viewModel.toggleRecording()
//                    }.frame(width: 100, height: 100)
//
//                    Text(viewModel.isRecording ? "Listening…" : "Tap to speak")
//                        .font(.system(.footnote, design: .rounded))
//                        .foregroundStyle(.secondary)
//                        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
//                }
//                .padding(.vertical, 8)
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
        }.onChange(of: viewModel.isTTSSpeaking) { speaking in
            if speaking { lastSpokeAt = Date() }
        }.sheet(isPresented: $showingSummary) {
            if let s = viewModel.currentSummary {
                SummaryDetailView(summary: s)
            } else if viewModel.isGeneratingSummary {
                ProgressView("Creating your summary…").padding()
            } else if let err = viewModel.summaryError {
                VStack(spacing: 12) {
                    Text("Couldn’t create summary").font(.headline)
                    Text(err).font(.footnote).foregroundStyle(.secondary)
                    Button("Close") { showingSummary = false }
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    Text("Nothing to summarize yet").font(.headline)
                    Button("Close") { showingSummary = false }
                }
                .padding()
            }
        }
    }

    
    
//    private var orbConfig: OrbConfiguration {
//        // Base behavior from your state
//        let isSpeaking = viewModel.isTTSSpeaking
//        let level = Double(viewModel.rmsLevel)  // 0…1 (use 0 if you haven’t wired this yet)
//
//        // Feel knobs
//        let baseSpeed = isSpeaking ? 90.0 : 55.0
//        let speed = baseSpeed * (1 + 0.35 * level) // gently “stirs” with voice energy
//        let core  = (isSpeaking ? 1.10 : 0.90) + 0.20 * level
//
//        return OrbConfiguration(
//            backgroundColors: [
//                Color(hue: 0.66, saturation: 0.70, brightness: 0.95), // purple
//                Color(hue: 0.54, saturation: 0.90, brightness: 0.95), // aqua
//                Color(hue: 0.83, saturation: 0.55, brightness: 0.98)  // pink
//            ],
//            glowColor: .white,
//            coreGlowIntensity: core,
//            showBackground: true,
//            showWavyBlobs: true,
//            showParticles: true,
//            showGlowEffects: true,
//            showShadow: true,
//            speed: speed
//        )
//    }
    
//    private var orbConfig: OrbConfiguration {
//        let isSpeaking = viewModel.isTTSSpeaking
//        // 0…1 clamp (in case RMS sometimes exceeds 1.0)
//        let level = max(0, min(1, Double(viewModel.rmsLevel)))
//        
//        
//
//        // Color to orb
//        let warmSunset: [Color] = [
//          Color(hue: 0.08, saturation: 0.90, brightness: 1.00), // tangerine
//          Color(hue: 0.05, saturation: 0.75, brightness: 0.98), // deep coral
//          Color(hue: 0.10, saturation: 0.55, brightness: 1.00)  // apricot
//        ]
//        let warmGlow = Color(hue: 0.10, saturation: 0.20, brightness: 1.00) // warm white
//        let warmParticles = Color(hue: 0.08, saturation: 0.85, brightness: 1.00)
//
//
//        // Feel knobs (slightly brighter core for “speaking”)
//        // Calmer base speeds
//        let baseSpeed = isSpeaking ? 60.0 : 38.0
//        
//        // Small coupling to voice + clamp absolute speed
//        let target = baseSpeed * (1 + 0.15 * level)
//        let speed = min(max(target, 24.0), 72.0)   // <-- hard floor/ceiling
//        let core  = (isSpeaking ? 1.06 : 0.92) + 0.12 * level
//
//        return OrbConfiguration(
//            backgroundColors: warmSunset,
//            glowColor: warmGlow,
//            coreGlowIntensity: core,
//            showBackground: true,
//            showWavyBlobs: true,
//            showParticles: true,
//            showGlowEffects: true,
//            showShadow: true,
//            speed: speed
//            // If your OrbConfiguration has this field; if not, ignore:
////            particleColor: particles
//        )
//    }
//    
//    // Helper inside ChatView
//    private func orbConfigReplacingSpeed(_ speed: Double) -> OrbConfiguration {
//        var c = orbConfig
//        c.speed = speed
//        return c
//    }
    
    private func makeOrbConfig(speed: Double) -> OrbConfiguration {
        let isSpeaking = viewModel.isTTSSpeaking
        let level = Double(min(max(viewModel.rmsLevel, 0), 1))

        let core = (isSpeaking ? 1.04 : 0.92) + 0.10 * level  // gentle core change
        
        // Color to orb
        let warmSunset: [Color] = [
          Color(hue: 0.08, saturation: 0.90, brightness: 1.00), // tangerine
          Color(hue: 0.05, saturation: 0.75, brightness: 0.98), // deep coral
          Color(hue: 0.10, saturation: 0.55, brightness: 1.00)  // apricot
        ]
        let warmGlow = Color(hue: 0.10, saturation: 0.20, brightness: 1.00) // warm white
        let warmParticles = Color(hue: 0.08, saturation: 0.85, brightness: 1.00)

        return OrbConfiguration(
            backgroundColors: warmSunset,
            glowColor: warmGlow,
            coreGlowIntensity: core,
            showBackground: true,
            showWavyBlobs: true,
            showParticles: true,
            showGlowEffects: true,
            showShadow: true,
            speed: speed
        )
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

