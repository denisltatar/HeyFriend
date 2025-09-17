//
//  SessionTimerService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 9/17/25.
//

import Foundation
import Combine
import QuartzCore

final class SessionTimerService {
    struct State {
        let elapsed: TimeInterval
        let remaining: TimeInterval
        let hasWarned: Bool
        let isOverLimit: Bool
    }

    private let startDate: Date
    private let maxDuration: TimeInterval
    private let warnAtSeconds: TimeInterval   // e.g. 300s in prod, 10s in tests

    private var displayLink: CADisplayLink?
    private let subject = CurrentValueSubject<State, Never>(
        .init(elapsed: 0, remaining: 0, hasWarned: false, isOverLimit: false)
    )

    var publisher: AnyPublisher<State, Never> { subject.eraseToAnyPublisher() }

    init(startedAt: Date,
         maxDuration: TimeInterval = 30 * 60,
         warnAtSeconds: TimeInterval = 300) {
        self.startDate = startedAt
        self.maxDuration = max(0, maxDuration)
        self.warnAtSeconds = max(0, warnAtSeconds)
        tick()
        start()
    }

    deinit { stop() }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Private

    private func start() {
        let link = CADisplayLink(target: self, selector: #selector(onTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func onTick() { tick() }

    private func tick() {
        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(startDate))
        let remaining = max(0, maxDuration - elapsed)
        let warned = remaining <= warnAtSeconds
        let over = remaining <= 0
        subject.send(.init(elapsed: elapsed, remaining: remaining, hasWarned: warned, isOverLimit: over))
    }
}
