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

// MARK: - Models for Tone Card

struct ToneStat: Identifiable {
    let id = UUID()
    let label: String       // e.g., "Calm"
    let percent: Double     // 0...1 (e.g., 0.45)
    let delta: Double       // -1...1 change vs previous period (e.g., +0.10)
    let color: Color        // brand color per tone
}

// MARK: - Model
struct TonePoint: Identifiable, Equatable {
    let id: String
    let label: String        // e.g., "Calm"
    let value: Double        // 0...1 normalized intensity for the range/window
    
    init(label: String, value: Double) {
        self.label = label
        self.value = value
        self.id = label
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
                                          ? Color.orange // 🔥 brand orange when active
                                          : Color(.secondarySystemBackground))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isSelected
                                            ? Color.orange.opacity(0.8) // 🔥 border matches
                                            : Color.primary.opacity(0.06),
                                            lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(isSelected ? 0.06 : 0), radius: 10, x: 0, y: 4)
                            .foregroundStyle(isSelected ? .white : .secondary) // 🔥 white text when active
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
                
                // Header + Range Selector
                Section {
                    InsightsHeader(selected: $selectedRange)
//                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
//                        .padding(.horizontal, )
                }

                // Tone Card Trends
//                Section {
//                    ToneTrendsCard(
//                        stats: [
//                            ToneStat(label: "Calm",      percent: 0.45, delta:  0.10, color: .teal),
//                            ToneStat(label: "Hopeful",   percent: 0.32, delta:  0.00, color: .orange), // brand tone
//                            ToneStat(label: "Reflective",percent: 0.23, delta: -0.07, color: .indigo)
//                        ],
//                        weekSeries: [0.26, 0.31, 0.28, 0.40, 0.38, 0.45, 0.47] // sample data
//                    )
//                }
                
                
                Section {
                    let toneOrder = ToneBucket.allCases.map(\.rawValue)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tone Radar")
                            .font(.headline.bold())
                        Text("Distribution across your selected period")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if vm.isLoadingRadar {
                            ProgressView().frame(height: 220)
                        } else if vm.radarPoints.isEmpty || vm.radarPoints.allSatisfy({ $0.value <= 0 }) {
                            EmptyRadarState()
                        } else {
                            RadarChart(axesOrder: toneOrder, points: vm.radarPoints)
                                .frame(height: 280)
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.thinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 1))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
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
                    // Updating for Tone Radar
                    await vm.loadRadar(rangeDays: selectedRange.days)
                }
            }

            // React to range changes (plug in your VM range-based fetch here)
            .onChange(of: selectedRange) { _, newValue in
                Task {
                    // Example mapping—replace with your VM API that accepts a window.
                    // await vm.loadHistory(rangeDays: newValue.days)
                    await vm.loadHistory()
                    // Adding to sensitivity for Tone Radar to responsive for date changes
                    await vm.loadRadar(rangeDays: newValue.days)
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

// MARK: - Sparkline

private struct SparklineView: View {
    let values: [Double]                // e.g., [0.10, 0.25, 0.22, ...] for 7 days
    let lineWidth: CGFloat = 2
    let showDots: Bool = true

    private var normalized: [CGFloat] {
        guard let minV = values.min(), let maxV = values.max(), maxV > minV else {
            return values.map { _ in 0.5 } // flat line if no variance
        }
        return values.map { CGFloat(($0 - minV) / (maxV - minV)) }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let step = values.count > 1 ? w / CGFloat(values.count - 1) : 0

            // Line path
            let path = Path { p in
                guard !normalized.isEmpty else { return }
                p.move(to: CGPoint(x: 0, y: h - normalized[0] * h))
                for i in 1..<normalized.count {
                    p.addLine(to: CGPoint(x: CGFloat(i) * step, y: h - normalized[i] * h))
                }
            }

            // Area fill (soft)
            let area = Path { p in
                guard !normalized.isEmpty else { return }
                p.move(to: CGPoint(x: 0, y: h))
                for i in 0..<normalized.count {
                    p.addLine(to: CGPoint(x: CGFloat(i) * step, y: h - normalized[i] * h))
                }
                p.addLine(to: CGPoint(x: w, y: h))
                p.closeSubpath()
            }

            area
                .fill(LinearGradient(colors: [
                    Color.orange.opacity(0.12),
                    Color.orange.opacity(0.02)
                ], startPoint: .top, endPoint: .bottom))

            path
                .stroke(Color.orange, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))

            if showDots {
                ForEach(values.indices, id: \.self) { i in
                    let x = CGFloat(i) * step
                    let y = h - normalized[i] * h
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }
            }
        }
        .frame(height: 56)
        .accessibilityHidden(true)
    }
}

// MARK: - Tone Trends Card

private struct ToneTrendsCard: View {
    let title: String = "Tone Trends"
    let subtitle: String = "This week at a glance"
    let stats: [ToneStat]              // top 2–3 tones
    let weekSeries: [Double]           // 7 values for sparkline (dominant tone % per day)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Titles
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            // Stats row (Calm / Hopeful / Reflective)
            HStack(spacing: 12) {
                ForEach(stats) { s in
                    ToneStatPill(stat: s)
                        .frame(maxWidth: .infinity)   // 👈 each pill stretches equally
                }
            }

            // Sparkline
            VStack(alignment: .leading, spacing: 6) {
                Text("Last 7 days")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                SparklineView(values: weekSeries)
                    .frame(maxWidth: .infinity)
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
        .padding(.horizontal, 16)  // spacing from screen edges in List row
        .listRowInsets(EdgeInsets())           // align with History width
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

private struct ToneStatPill: View {
    let stat: ToneStat

    private var arrowSymbol: (name: String, color: Color) {
        if stat.delta > 0.005 { return ("arrow.up", .green) }
        if stat.delta < -0.005 { return ("arrow.down", .red) }
        return ("arrow.left.and.right", .secondary)
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(stat.color.opacity(0.25))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text("\(Int(round(stat.percent * 100)))%")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: arrowSymbol.name)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(arrowSymbol.color)
                    Text(deltaString)
                        .font(.caption2)
                        .foregroundStyle(arrowSymbol.color)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var deltaString: String {
        let pct = Int(round(abs(stat.delta) * 100))
        if pct == 0 { return "↔︎ 0%" }
        return (stat.delta > 0 ? "+\(pct)%" : "-\(pct)%")
    }
}

// MARK: - Radar Chart
struct RadarChart: View {
    /// Set once; keeps axes locked in this order forever.
    let axesOrder: [String]                 // e.g. ["Calm","Hopeful","Reflective","Anxious","Stressed"]
    let points: [TonePoint]                 // current values for some/all of the axes
    let levels: Int = 5
    let showDots: Bool = true
    let labelPadding: CGFloat = 18
    let lineWidth: CGFloat = 2
    var strokeColor: Color = .orange
    var fillGradient: LinearGradient = LinearGradient(
        colors: [Color.orange.opacity(0.28), Color.orange.opacity(0.06)],
        startPoint: .top, endPoint: .bottom
    )

    @State private var animValues: [Double] = []

    // Map incoming `points` to the canonical order (missing tones -> 0)
    private var orderedValues: [Double] {
        let dict = Dictionary(uniqueKeysWithValues: points.map { ($0.label, max(0, min(1, $0.value))) })
        return axesOrder.map { dict[$0] ?? 0.0 }
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
            let radius = (size/2) - labelPadding
            let n = max(axesOrder.count, 3)
            let values = animValues.isEmpty ? orderedValues : animValues
            let pts = polygonPoints(values: values, center: center, radius: radius, n: n)

            ZStack {
                // Rings
                ForEach(1...levels, id: \.self) { level in
                    let frac = CGFloat(level) / CGFloat(levels)
                    ringPath(n: n, radius: radius * frac, center: center)
                        .stroke(.secondary.opacity(0.25), lineWidth: 1)
                }
                // Spokes
                ForEach(0..<n, id: \.self) { i in
                    let angle = angleFor(index: i, total: n)
                    Path { p in
                        p.move(to: center)
                        p.addLine(to: pointOnCircle(center: center, radius: radius, angle: angle))
                    }.stroke(.secondary.opacity(0.25), lineWidth: 1)
                }
                // Labels
                ForEach(axesOrder.indices, id: \.self) { i in
                    let angle = angleFor(index: i, total: n)
                    let labelPos = pointOnCircle(center: center, radius: radius + 12, angle: angle)

                    Text(axesOrder[i])
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .position(labelPos)            // exact coordinates — no extra frame
                }
                // Fill
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                    p.closeSubpath()
                }
                .fill(fillGradient)
                // Stroke
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                    p.closeSubpath()
                }
                .stroke(strokeColor, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                // Dots
                if showDots {
                    ForEach(pts.indices, id: \.self) { i in
                        Circle().fill(strokeColor).frame(width: 6, height: 6).position(pts[i])
                    }
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.35)) {
                    animValues = orderedValues
                }
            }
            .onChange(of: points) { _, _ in
                withAnimation(.easeInOut(duration: 0.35)) {
                    animValues = orderedValues
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Radar chart of tone intensities")
    }

    // MARK: - Geometry helpers
    
    private func angleFor(index i: Int, total n: Int) -> Angle {
        Angle(degrees: (Double(i) / Double(n)) * 360.0 - 90.0) // start at top, clockwise
    }
    
    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        let r = CGFloat(angle.radians)
        return CGPoint(x: center.x + radius * cos(r), y: center.y + radius * sin(r))
    }
    
    private func ringPath(n: Int, radius: CGFloat, center: CGPoint) -> Path {
        let verts = (0..<n).map { i in pointOnCircle(center: center, radius: radius, angle: angleFor(index: i, total: n)) }
        return Path { p in
            guard let first = verts.first else { return }
            p.move(to: first)
            for v in verts.dropFirst() { p.addLine(to: v) }
            p.closeSubpath()
        }
    }
    
    private func polygonPoints(values: [Double], center: CGPoint, radius: CGFloat, n: Int) -> [CGPoint] {
        values.enumerated().map { (i, v) in
            let r = radius * CGFloat(max(0, min(1, v)))
            let a = angleFor(index: i, total: n)
            return pointOnCircle(center: center, radius: r, angle: a)
        }
    }
    
//    private func textAlignment(for angle: Angle) -> Alignment {
//        let deg = angle.degrees.truncatingRemainder(dividingBy: 360)
//        if deg > -90 && deg < 90 { return .leading }
//        if deg < -90 || deg > 90 { return .trailing }
//        return .center
//    }
//    
//    private func adjustedLabelPosition(for pos: CGPoint, center: CGPoint, angle: Angle) -> CGPoint {
//        let r = CGFloat(angle.radians)
//        return CGPoint(x: pos.x + cos(r)*8, y: pos.y + sin(r)*8)
//    }
}

// MARK: - Tone Radar Empty State

// Consider the radar "empty" when there are no points or all values are zero.
private func isRadarEmpty(_ points: [TonePoint]) -> Bool {
    points.isEmpty || points.allSatisfy { $0.value <= 0 }
}

private struct EmptyRadarState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "hexagon")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("No tone data yet")
                .font(.headline)
            Text("Start a session and we’ll chart your tone distribution here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 150) // nice presence in the card
    }
}
