//
//  SummaryDetailView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/19/25.
//

import Foundation
import SwiftUI

struct SummaryDetailView: View {
    let summary: SessionSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    
                    // Session Summary (bullets)
                    Text("Session Summary")
                        .font(.title3).bold()

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(summary.summary, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text(bullet)
                            }
                        }
                    }
                    
                    // Tone
                    toneSection

                    // Language Patterns
                    languageSection

                    // Personalized Recommendation (green card)
                    if let rec = summary.recommendation, !rec.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                Text("Personalized Recommendation").bold()
                                Spacer()
                            }
                            Text(rec)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.green.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.green.opacity(0.25), lineWidth: 1)
                        )
                    }

                    // Timestamp
                    Text(summary.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    // MARK: - Components

    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "heart")
                Text("Primary Tone").font(.headline)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(summary.tone).font(.title3).bold()
                if let note = summary.toneNote, !note.isEmpty {
                    Text(note).foregroundStyle(.secondary)
                }
                if let supports = summary.supportingTones, !supports.isEmpty {
                    let list = supports.joined(separator: ", ")
                    Text("Supporting Tones: \(list)")
                        .font(.subheadline)
                        .foregroundStyle(.purple)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                Text("Language Patterns").font(.headline)
            }
            if let lang = summary.language {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Text("Repeated words:")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .leading)
                        Text(lang.repeatedWords.isEmpty ? "—" : lang.repeatedWords.map { "\"\($0)\"" }.joined(separator: ", "))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(alignment: .top) {
                        Text("Thinking style:")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .leading)
                        Text(lang.thinkingStyle.isEmpty ? "—" : lang.thinkingStyle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(alignment: .top) {
                        Text("Emotional indicators:")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .leading)
                        Text(lang.emotionalIndicators.isEmpty ? "—" : lang.emotionalIndicators)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            } else {
                Text("We didn’t detect clear language patterns this time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
