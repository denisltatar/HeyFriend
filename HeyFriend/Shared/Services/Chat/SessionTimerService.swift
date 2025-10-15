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
    private let warnAtElapsed: TimeInterval

    private var displayLink: CADisplayLink?
    private let subject = CurrentValueSubject<State, Never>(
        .init(elapsed: 0, remaining: 0, hasWarned: false, isOverLimit: false)
    )

    var publisher: AnyPublisher<State, Never> { subject.eraseToAnyPublisher() }

    init(startedAt: Date,
         maxDuration: TimeInterval = 20 * 60,
         warnAtElapsed: TimeInterval = 15 * 60) {
        self.startDate = startedAt
        self.maxDuration = max(0, maxDuration)
        self.warnAtElapsed = max(0, warnAtElapsed)
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
        let warned = remaining <= warnAtElapsed
        let over = remaining <= 0
        subject.send(.init(elapsed: elapsed, remaining: remaining, hasWarned: warned, isOverLimit: over))
    }
}
