//
//  TextToSpeechService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/8/25.
//

import Foundation
import AVFoundation

final class TextToSpeechService: NSObject {
    static let shared = TextToSpeechService()
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String) {
        // smoother audio handoff
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let utterance = AVSpeechUtterance(string: text)

        // pick best available English voice (prefers Enhanced/Siri)
        utterance.voice = bestNaturalEnglishVoice()

        // slower + slightly higher pitch sounds more human
        utterance.rate = 0.45            // 0.0–1.0; default ~0.5. Try 0.42–0.52
        utterance.pitchMultiplier = 1.05 // 0.5–2.0
        utterance.postUtteranceDelay = 0.05

        // respect user’s Spoken Content settings if enabled
        utterance.prefersAssistiveTechnologySettings = true

        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func bestNaturalEnglishVoice() -> AVSpeechSynthesisVoice? {
        // 1) Prefer Enhanced/Siri voices, else fall back to any en-* voice
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let english = voices.filter { $0.language.hasPrefix("en") }

        // Prefer higher quality first (Enhanced > Default), then Siri name if present
        let sorted = english.sorted {
            if $0.quality != $1.quality { return $0.quality.rawValue > $1.quality.rawValue }
            let aIsSiri = $0.name.localizedCaseInsensitiveContains("siri")
            let bIsSiri = $1.name.localizedCaseInsensitiveContains("siri")
            if aIsSiri != bIsSiri { return aIsSiri } // Siri first
            return $0.name < $1.name
        }

        return sorted.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}
