//
//  TextToSpeechService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/8/25.
//

import Foundation
import AVFoundation

extension Notification.Name {
    static let ttsDidStart  = Notification.Name("ttsDidStart")
    static let ttsDidFinish = Notification.Name("ttsDidFinish")
}

final class TextToSpeechService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = TextToSpeechService()
    private let synth = AVSpeechSynthesizer()
    private(set) var isSpeaking = false

    override init() {
        super.init()
        synth.delegate = self
        synth.usesApplicationAudioSession = true
    }

    func speak(_ text: String) {
        let u = AVSpeechUtterance(string: text)
        u.voice = bestNaturalEnglishVoice()
        u.rate = 0.45
        u.pitchMultiplier = 1.05
        u.postUtteranceDelay = 0.05
        u.prefersAssistiveTechnologySettings = true

        synth.speak(u)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }

    // MARK: Delegate
//    func speechSynthesizer(_ s: AVSpeechSynthesizer,
//                           willSpeakRangeOfSpeechString _: NSRange,
//                           utterance _: AVSpeechUtterance) {
//        NotificationCenter.default.post(name: .ttsBeat, object: nil)
//    }
    
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart _: AVSpeechUtterance) {
        isSpeaking = true
        NotificationCenter.default.post(name: .ttsDidStart, object: nil)
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        isSpeaking = false
        NotificationCenter.default.post(name: .ttsDidFinish, object: nil)
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) {
        isSpeaking = false
        NotificationCenter.default.post(name: .ttsDidFinish, object: nil)
    }

    private func bestNaturalEnglishVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        let sorted = voices.sorted {
            if $0.quality != $1.quality { return $0.quality.rawValue > $1.quality.rawValue }
            let aSiri = $0.name.localizedCaseInsensitiveContains("siri")
            let bSiri = $1.name.localizedCaseInsensitiveContains("siri")
            if aSiri != bSiri { return aSiri }
            return $0.name < $1.name
        }
        return sorted.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}
