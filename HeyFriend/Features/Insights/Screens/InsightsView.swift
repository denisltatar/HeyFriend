//
//  InsightsView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/19/25.
//

import Foundation
import SwiftUI

// MARK: - Styled Insights (History-only for now)
struct InsightsView: View {
    @StateObject private var vm = InsightsViewModel()

    var body: some View {
        Section("This Week at a Glance") {
            Text("Mood trend and top emotion will appear here.")
        }
        NavigationStack {
            
            List {
                
                Section {
                    if vm.rows.isEmpty && !vm.isLoading && vm.error == nil {
                        EmptyHistoryState()
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    ForEach(vm.rows) { row in
                        Button {
                            Task { await vm.openSessionDetail(for: row.id) }
                        } label: {
                            HistoryCardRow(title: row.title,
                                           subtitle: row.subtitle,
                                           date: row.createdAt)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    HistorySectionHeader(count: vm.rows.count)
                        .textCase(nil)
                        .padding(.top, 6)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            )
            .overlay {
                if vm.isLoading {
                    ProgressView().controlSize(.large)
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .refreshable { await vm.loadHistory() }
            .task { await vm.loadHistory() }
            .navigationTitle("Insights")
            .sheet(item: $vm.selectedSummary) { sum in
                SummaryDetailView(summary: sum)
            }
            .alert("Error", isPresented: .constant(vm.error != nil)) {
                Button("OK") { vm.error = nil }
            } message: {
                Text(vm.error ?? "")
            }
        }
    }
}

// MARK: - Components

/// Pretty header with icon + pill count
private struct HistorySectionHeader: View {
    let count: Int
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .imageScale(.large)
                .foregroundStyle(.secondary)

            Text("History")
                .font(.title2).bold()

            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.blue.opacity(0.12))
                    )
                    .overlay(
                        Capsule().stroke(Color.blue.opacity(0.22), lineWidth: 1)
                    )
                    .foregroundStyle(.blue)
                    .accessibilityLabel("\(count) items")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
    }
}

/// Frosted card row with clean hierarchy
private struct HistoryCardRow: View {
    let title: String
    let subtitle: String
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title (summary snippet)
            Text(title.isEmpty ? "Session summary" : title)
                .font(.body.weight(.semibold))
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            HStack(spacing: 8) {
                if !subtitle.isEmpty {
                    HStack(spacing: 4) { // tighter spacing than Label
                        Image(systemName: "waveform.path.ecg")
                            .font(.caption)
                        Text(subtitle)
                    }
                }
                
                Spacer(minLength: 4)
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)          // smaller icon so it hugs the text nicely
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
}

/// Empty state that fits the new style
private struct EmptyHistoryState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No sessions yet")
                .font(.headline)
            Text("Start your first conversation and your summary will show up here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16).fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
