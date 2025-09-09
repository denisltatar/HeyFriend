//
//  TextToSpeechService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/8/25.
//

//
//  TextToSpeechService.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/8/25.
//  Updated: adds OpenAI TTS with Apple TTS fallback.
//

import Foundation
import AVFoundation
// ADD for CADisplayLink
import QuartzCore

extension Notification.Name {
    static let ttsDidStart  = Notification.Name("ttsDidStart")
    static let ttsDidFinish = Notification.Name("ttsDidFinish")
    static let ttsOutputLevel = Notification.Name("ttsOutputLevel")
}

final class TextToSpeechService: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    static let shared = TextToSpeechService()

    // Apple TTS (fallback)
    private let synth = AVSpeechSynthesizer()

    // OpenAI playback
    private var player: AVAudioPlayer?
    private let playbackQueue = DispatchQueue(label: "heyfriend.tts.playback")

    private(set) var isSpeaking = false
    
    // MARK: - TTS Output Metering
    private var meterLink: CADisplayLink?
    private var lastTTSLevel: Float = 0    // smoothed 0..1
    private let ttsSmoothAlpha: Float = 0.25

    override init() {
        super.init()
        synth.delegate = self
        synth.usesApplicationAudioSession = true
    }

    // Public API (same as before)
    func speak(_ text: String) {
        // Try OpenAI first (device-friendly). If no key, use Apple TTS.
        if let apiKey = loadAPIKey(), !apiKey.isEmpty {
            speakWithOpenAI(text, apiKey: apiKey)
        } else {
            speakWithApple(text)
        }
    }

    func stop() {
        // Stop whichever engine is active
        if let p = player, p.isPlaying {
            p.stop()
            player = nil
            isSpeaking = false
            NotificationCenter.default.post(name: .ttsDidFinish, object: nil)
        }
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
            // delegate will post finish
        }
        restoreVoiceChatMode()
    }
    
    // MARK: - Speaker mode - making the speaker louder for users
    
    private func enterSpeakerPlaybackMode() {
        let session = AVAudioSession.sharedInstance()
        // Stay in .playAndRecord so input stays valid for barge-in
        // Just relax the processing and force speaker
        try? session.setMode(.default) // drop AEC/AGC of .voiceChat while speaking
        try? session.overrideOutputAudioPort(.speaker)
        // No setActive(false) here; don’t tear down the engine mid-TTS
    }

    private func restoreVoiceChatMode() {
        let session = AVAudioSession.sharedInstance()
            // Return to your original mic-friendly profile
            try? session.setMode(.voiceChat)
            // Keep .defaultToSpeaker from your initial setCategory in the VM
            // Don’t call setActive(false) here either
    }

    // MARK: - OpenAI TTS
    
    // Documentation - https://platform.openai.com/docs/guides/text-to-speech
    private func speakWithOpenAI(_ text: String, apiKey: String) {
        // Fetch synthesized audio off the main thread
        Task {
            do {
                // Build request
                struct Body: Encodable {
                    let model: String = "gpt-4o-mini-tts"
//                    let model: String = "gpt-4o-mini-tts-1"
//                    let model: String = "gpt-4o-tts"
                    let voice: String = "echo" // voice change option
                    /* Options for voices:
                     alloy
                     ash
                     ballad
                     coral
                     echo
                     fable
                     nova
                     onyx
                     sage
                     shimmer
                     */
                    let input: String
                    let format: String = "aac"  // "m4a/mp3" | "aac" | "wav" | "opus" also ok
                }

                var req = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/speech")!)
                req.httpMethod = "POST"
                req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                req.addValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONEncoder().encode(Body(input: text))

                let (data, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode >= 300 {
                    // Fallback to Apple TTS on API error
                    let snippet = String(data: data, encoding: .utf8) ?? "<no body>"
                    print("OpenAI TTS HTTP \(http.statusCode): \(snippet)")
                    self.speakWithApple(text)
                    return
                }

                // Write to a temp file
                let fileURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("heyfriend-tts-\(UUID().uuidString).mp3")
                try data.write(to: fileURL, options: .atomic)

                // Start playback on main
                try await MainActor.run {
                    do {
                        // Configure loudspeaker session for TTS playback
                        self.enterSpeakerPlaybackMode()
                        
                        // NOTE: Your ChatViewModel already configures AVAudioSession
                        let newPlayer = try AVAudioPlayer(contentsOf: fileURL)
                        newPlayer.delegate = self
                        newPlayer.isMeteringEnabled = true
                        newPlayer.prepareToPlay()
                        newPlayer.volume = 1.0  // 🔊 ensure full-scale output

                        self.playbackQueue.sync {
                            self.player?.stop()
                            self.player = newPlayer
                        }

                        self.isSpeaking = true
                        NotificationCenter.default.post(name: .ttsDidStart, object: nil)

                        self.playbackQueue.async {
                            self.player?.play()
                            // Begin metering volume for assistanct voice's orb to 'breath/nudge'
                            self.startMetering()
                        }
                    } catch {
                        print("AVAudioPlayer init failed: \(error)")
                        self.speakWithApple(text) // fallback if playback fails
                    }
                }
            } catch {
                print("OpenAI TTS network error: \(error)")
                self.speakWithApple(text) // fallback if request fails
            }
        }
    }

    // MARK: - Apple TTS fallback

    private func speakWithApple(_ text: String) {
        // Configure loudspeaker session for TTS playback
        enterSpeakerPlaybackMode()
        
        let u = AVSpeechUtterance(string: text)
        u.voice = bestNaturalEnglishVoice()
        u.rate = 0.45
        u.pitchMultiplier = 1.05
        u.postUtteranceDelay = 0.05
        u.prefersAssistiveTechnologySettings = true
        u.volume = 1.0  // 🔊 explicit max

        isSpeaking = true
        NotificationCenter.default.post(name: .ttsDidStart, object: nil)
        synth.speak(u)
    }

    // MARK: - Helpers

    private func loadAPIKey() -> String? {
        // Prefer scheme env for Simulator/Debug
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !env.isEmpty {
            return env
        }
        // Fallback to Info.plist for TestFlight/device
        if let key = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String, !key.isEmpty {
            return key
        }
        return nil
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

    // MARK: - Delegates

    // Apple TTS delegate
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart _: AVSpeechUtterance) {
        isSpeaking = true
        // (start already posted above; keep symmetrical)
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        isSpeaking = false
        NotificationCenter.default.post(name: .ttsDidFinish, object: nil)
        restoreVoiceChatMode()

    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) {
        isSpeaking = false
        NotificationCenter.default.post(name: .ttsDidFinish, object: nil)
        restoreVoiceChatMode()
    }

    // OpenAI playback delegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isSpeaking = false
        stopMetering()
        NotificationCenter.default.post(name: .ttsDidFinish, object: nil)
        restoreVoiceChatMode()
        playbackQueue.sync { self.player = nil }
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("AVAudioPlayer decode error: \(error?.localizedDescription ?? "unknown")")
        isSpeaking = false
        stopMetering()
        NotificationCenter.default.post(name: .ttsDidFinish, object: nil)
        restoreVoiceChatMode()
        playbackQueue.sync { self.player = nil }
    }
    
    // Helpers to start/stop metering (of TTS volume)
    private func startMetering() {
        stopMetering()
        meterLink = CADisplayLink(target: self, selector: #selector(tickMeter))
        meterLink?.add(to: .main, forMode: .common)
    }

    private func stopMetering() {
        meterLink?.invalidate()
        meterLink = nil
        lastTTSLevel = 0
        // send a final “0 level” so the UI settles
        NotificationCenter.default.post(name: .ttsOutputLevel, object: nil, userInfo: ["level": CGFloat(0)])
    }

    @objc private func tickMeter() {
        guard let p = player else { return }
        p.updateMeters()
        // dB range roughly [-60, 0]; map to 0..1
        let power = p.averagePower(forChannel: 0)
        let linear = max(0, min(1, pow(10, power / 20)))   // convert dB to linear (0..1)
        // low-pass smoothing
        lastTTSLevel = lastTTSLevel * (1 - ttsSmoothAlpha) + linear * ttsSmoothAlpha
        NotificationCenter.default.post(name: .ttsOutputLevel, object: nil, userInfo: ["level": CGFloat(lastTTSLevel)])
    }

}
