//
//  SessionsHomeView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/19/25.
//

import Foundation
import SwiftUI

struct SessionsHomeView: View {
    @State private var goToChat = false
    @State private var isPressed = false

    // Pass the selected suggestion to ChatView via AppStorage
    @AppStorage("HF_initialPrompt") private var initialPrompt: String = ""

    // MARK: - Suggestions
    struct Suggestion: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let prompt: String
        let icon: String
        let tag: String
    }

    private var quickChips: [Suggestion] {
        [
            .init(title: "Feeling overwhelmed", prompt: "I’m feeling overwhelmed today. Can we sort through what’s weighing on me and name the top stressors?", icon: "bolt.heart.fill", tag: "Emotions"),
            .init(title: "Untangling thoughts", prompt: "My thoughts feel tangled. Help me slow down and make sense of what’s looping.", icon: "brain.head.profile", tag: "Clarity"),
            .init(title: "Difficult conversation", prompt: "I have a hard conversation coming up. Can we plan what I want to say and how to say it?", icon: "bubble.left.and.bubble.right.fill", tag: "Communication"),
            .init(title: "Motivation slump", prompt: "I’m low on motivation. Let’s find tiny next steps that feel doable.", icon: "chart.line.uptrend.xyaxis", tag: "Habits"),
            .init(title: "Setting boundaries", prompt: "I struggle to set boundaries without guilt. Can we work on a simple boundary script?", icon: "shield.lefthalf.filled", tag: "Boundaries"),
            .init(title: "Racing mind at night", prompt: "My mind races at night. Could we practice a wind-down routine I can try this week?", icon: "moon.zzz.fill", tag: "Sleep")
        ]
    }

    private var themed: [(section: String, items: [Suggestion])] {
        [
            ("Stress & Overwhelm", [
                .init(title: "Sort my stress", prompt: "Help me sort my stress into: things I control, influence, or can release.", icon: "list.bullet.rectangle.portrait.fill", tag: "Stress"),
                .init(title: "Grounding check-in", prompt: "Guide me through a short grounding check-in to reduce tension.", icon: "leaf.fill", tag: "Calm"),
            ]),
            ("Relationships & Boundaries", [
                .init(title: "People-pleasing", prompt: "I say yes too much. Help me practice a kind ‘no’.", icon: "person.2.wave.2.fill", tag: "Boundaries"),
                .init(title: "Conflict repair", prompt: "I want to repair a recent conflict. Let’s draft a message that owns my part.", icon: "bandage.fill", tag: "Repair"),
            ]),
            ("Habits & Motivation", [
                .init(title: "Tiny plan", prompt: "I want a tiny, specific plan for the next 24 hours that moves me forward.", icon: "checkmark.seal.fill", tag: "Action"),
                .init(title: "Procrastination", prompt: "I’m procrastinating. Help me break the task into the smallest next step.", icon: "hourglass", tag: "Action"),
            ]),
            ("Work & Career", [
                .init(title: "Work anxiety", prompt: "Work is spiking my anxiety. Can we reframe the stories I’m telling myself based on things at work?", icon: "briefcase.fill", tag: "Career"),
                .init(title: "Feedback prep", prompt: "I’m nervous to ask for feedback. Let’s script a short, clear request.", icon: "envelope.open.fill", tag: "Career"),
            ]),
            ("Self-Talk & Identity", [
                .init(title: "Harsh self-talk", prompt: "My self-talk is harsh. Help me rewrite it to be firm and kind.", icon: "quote.bubble.fill", tag: "Self-talk"),
                .init(title: "Values compass", prompt: "Help me name my top 3 values and one way to live them this week.", icon: "star.circle.fill", tag: "Values"),
            ]),
            ("Meaning & Faith", [
                .init(title: "Doubt & hope", prompt: "I’m wrestling with doubt and hope. Can we reflect on both with honesty?", icon: "sparkles", tag: "Meaning"),
                .init(title: "Gratitude scan", prompt: "Guide me through a short gratitude scan for today.", icon: "sun.min.fill", tag: "Gratitude"),
            ])
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                Text("Talk it out whenever you’re ready.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Start button
                Button {
                    start(with: "")
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.white)
                        Text("Start Session")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.00, green: 0.72, blue: 0.34), // amber
                                Color(red: 1.00, green: 0.45, blue: 0.00)  // orange
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )
                    .shadow(color: Color(red: 1.00, green: 0.65, blue: 0.20).opacity(0.35),
                            radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.12), value: isPressed)
                .simultaneousGesture(DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
                )
                .padding(.horizontal)

                // Chips
                VStack(alignment: .leading, spacing: 12) {
                    Text("Not sure where to start?")
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickChips) { chip in
                                Button {
                                    start(with: chip.prompt)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: chip.icon)
                                        Text(chip.title)
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 14)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.orange.opacity(0.12))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Themed cards
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(themed, id: \.section) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.section)
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(section.items) { s in
                                    Button {
                                        start(with: s.prompt)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Image(systemName: s.icon)
                                                Text(s.title)
                                                    .font(.subheadline.weight(.semibold))
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.leading)
                                                Spacer(minLength: 0)
                                            }
                                            Text(s.tag)
                                                .font(.caption2)
                                                .padding(.vertical, 4)
                                                .padding(.horizontal, 8)
                                                .background(Capsule().fill(Color.orange.opacity(0.15)))
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(.background)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(Color.orange.opacity(0.20), lineWidth: 1)
                                        )
                                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                Spacer(minLength: 24)
            }
        }
        .navigationTitle("Sessions")
        // Programmatic navigation
        .background(
            NavigationLink(
                destination: ChatView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .tabBar),
                isActive: $goToChat,
                label: { EmptyView() }
            )
            .hidden()
        )
    }

    // MARK: - Helpers
    private func start(with prompt: String) {
        initialPrompt = prompt // ChatView should read this and consume it
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        goToChat = true
    }
}
