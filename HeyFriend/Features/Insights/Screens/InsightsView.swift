//
//  InsightsView.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/19/25.
//

import Foundation
import SwiftUI

// MARK: - Range Selector

private enum InsightsRange: String, CaseIterable, Identifiable {
    case seven = "7 Days"
    case thirty = "30 Days"
    case ninety = "3 Months"

    var id: Self { self }
    var days: Int {
        switch self {
        case .seven: return 7
        case .thirty: return 30
        case .ninety: return 90
        }
    }
}

private struct InsightsHeader: View {
    @Binding var selected: InsightsRange

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Insights")
                    .font(.title2.bold())
                Text("Understanding your emotional patterns")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Pills selector
            HStack(spacing: 10) {
                ForEach(InsightsRange.allCases) { range in
                    let isSelected = (range == selected)
                    Button {
                        selected = range
                    } label: {
                        Text(range.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(isSelected
                                          ? Color(.systemBackground)
                                          : Color(.secondarySystemBackground))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isSelected
                                            ? Color.primary.opacity(0.12)
                                            : Color.primary.opacity(0.06), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(isSelected ? 0.06 : 0), radius: 10, x: 0, y: 4)
                            .foregroundStyle(isSelected ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(range.rawValue)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}



// MARK: - Main View

struct InsightsView: View {
    @StateObject private var vm = InsightsViewModel()
    @State private var didLoadOnce = false

    @StateObject private var entitlements = EntitlementsViewModel()
    @State private var showPaywall = false

    // NEW: selected range state (defaults to 7 days)
    @State private var selectedRange: InsightsRange = .seven

    var body: some View {
        NavigationStack {
            List {
                // Header + Range Selector
                Section {
                    InsightsHeader(selected: $selectedRange)
//                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
//                        .padding(.horizontal, )
                }

                // Free / Plus pill
                // Show pill ONLY if not Plus
                if !entitlements.isPlus {
                    Section {
                        FreeSessionsPill(
                            isPlus: entitlements.isPlus,
                            remaining: entitlements.remaining,
                            limit: entitlements.freeLimit,
                            onUpgradeTap: { showPaywall = true }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }

                // History list
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
            // Start entitlements once
            .onAppear { entitlements.start() }

            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            // Prevent pull/overscroll while the sheet is up
            .scrollDisabled(showPaywall)

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

            // Pull to refresh respects scrollDisabled
            .refreshable { await vm.loadHistory() }

            // Initial load
            .task {
                if !didLoadOnce {
                    didLoadOnce = true
                    await vm.loadHistory()
                }
            }

            // React to range changes (plug in your VM range-based fetch here)
            .onChange(of: selectedRange) { _, newValue in
                Task {
                    // Example mapping—replace with your VM API that accepts a window.
                    // await vm.loadHistory(rangeDays: newValue.days)
                    await vm.loadHistory()
                }
            }

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
        // Attach the paywall sheet OUTSIDE the Navigation/List
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationBackgroundInteraction(.disabled)
        }
        .onDisappear { entitlements.stop() }
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
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.caption)
                        Text(subtitle)
                    }
                }

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
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
