//
//  ChatViewModel.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/8/25.
//

import Foundation
import AVFoundation
import Speech

class ChatViewModel: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var transcribedText: String = ""
    @Published var isRecording = false
    @Published var aiResponse: String = ""

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // VAD / auto-commit
    private var utteranceBuffer: String = ""
    private var lastVoiceTime: TimeInterval = 0
    private var silenceTimer: Timer?
    private let silenceHold: TimeInterval = 0.9     // commit after ~900ms of silence
    private let vadAmplitudeGate: Float = 0.013     // energy threshold for “speaking”
    private let minUtteranceChars = 2               // avoid committing “um”
    private var resumeGuardUntil: TimeInterval = 0
    
    // --- Barge-in + restart guards ---
    private var suspendAutoRestart = false
    private enum StopReason { case forTTS, userStop, transient }

    // Barge-in monitor
    private var bargeTapInstalled = false
    private var bargeStartTime: CFTimeInterval = 0
    private var bargeRequested = false
    private var bargeRMSGate: Float { max(0.015, vadAmplitudeGate * 1.2) } // adaptive
    private let bargeHold: TimeInterval = 0.12 // ~120ms of voice to trigger

    override init() {
        super.init()
        speechRecognizer.delegate = self
        requestPermissions()

        NotificationCenter.default.addObserver(self, selector: #selector(onTTSStart),
                                               name: .ttsDidStart, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onTTSFinish),
                                               name: .ttsDidFinish, object: nil)
        // Observers for handling interruptions
//        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption),
//            name: AVAudioSession.interruptionNotification, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange),
//            name: AVAudioSession.routeChangeNotification, object: nil)

    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        silenceTimer?.invalidate()
        NotificationCenter.default.removeObserver(self, name: .ttsDidStart, object: nil)
        NotificationCenter.default.removeObserver(self, name: .ttsDidFinish, object: nil)
    }

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                if status != .authorized {
                    self.transcribedText = "Speech recognition not authorized."
                }
            }
        }
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.transcribedText = "Microphone access denied."
                }
            }
        }
    }

    // Public control from the mic button
    func toggleRecording() { isRecording ? stopSession() : startSession() }

    // MARK: - Session lifecycle (continuous)
    func startSession() {
        guard !isRecording else { return }

        // Use play&record for smooth handoff with TTS
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord,
                                 mode: .voiceChat,
                                 options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        startRecognition()
        isRecording = true
        armSilenceTimer()
        lastVoiceTime = Date().timeIntervalSince1970
    }

    func stopSession() {
        isRecording = false
        stopRecognition(.userStop)
        silenceTimer?.invalidate()
        TextToSpeechService.shared.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        removeBargeInTap()
    }

    // MARK: - Recognition wiring
    private func startRecognition() {
        stopRecognition()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.recognitionRequest?.append(buffer)
            self.detectVoice(in: buffer) // update lastVoiceTime for VAD
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.utteranceBuffer = text
                    self.transcribedText = text
                }
                if result.isFinal {
                    self.commitUtteranceAndQuery()
                }
            }
            if error != nil {
                // Try to keep session alive after hiccups
                self.restartRecognitionSoon()
            }
        }

        audioEngine.prepare()
        try? audioEngine.start()
    }

    private func stopRecognition(_ reason: StopReason = .transient) {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        suspendAutoRestart = (reason == .forTTS) // block auto-restart while TTS speaks
    }

    private func restartRecognitionSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard self.isRecording else { return }
            guard !self.suspendAutoRestart else { return }
            self.startRecognition()
        }
    }

    // MARK: - Voice Activity Detection (RMS)
    private func detectVoice(in buffer: AVAudioPCMBuffer) {
        if Date().timeIntervalSince1970 < resumeGuardUntil { return }
        guard let ch = buffer.floatChannelData?.pointee else { return }
        let n = Int(buffer.frameLength)
        if n == 0 { return }

        var sum: Float = 0
        for i in 0..<n { sum += ch[i] * ch[i] }
        let rms = sqrt(sum / Float(n))

        if rms > vadAmplitudeGate {
            lastVoiceTime = Date().timeIntervalSince1970
            if TextToSpeechService.shared.isSpeaking {
                TextToSpeechService.shared.stop()                 // stop TTS now
                resumeGuardUntil = Date().timeIntervalSince1970 + 0.20
                // recognition will resume via your onTTSFinish() path
            }
        }
    }

    private func armSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard self.isRecording else { return }
            // If TTS is talking, don’t auto-commit; wait for finish
            if TextToSpeechService.shared.isSpeaking { return }

            let now = Date().timeIntervalSince1970
            let hasSpeech = self.utteranceBuffer.trimmingCharacters(in: .whitespacesAndNewlines).count >= self.minUtteranceChars

            if hasSpeech, now - self.lastVoiceTime > self.silenceHold {
                self.commitUtteranceAndQuery()
            }
        }
    }

    // MARK: - Turn commit → query → TTS → resume
    private func commitUtteranceAndQuery() {
        let userTurn = utteranceBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userTurn.isEmpty else { return }

        // Stop current recognition to avoid cross-talk with TTS
        stopRecognition(.forTTS)

        ChatService.shared.sendMessage(userTurn) { reply in
            DispatchQueue.main.async {
                self.aiResponse = (reply ?? "Sorry, I didn’t catch that. Can you try again?").trimmingCharacters(in: .whitespacesAndNewlines)
                TextToSpeechService.shared.speak(self.aiResponse)
                // After TTS finishes, onTTSFinish() will bring us back to listening
            }
        }

        // Prepare for next turn
        utteranceBuffer = ""
        lastVoiceTime = Date().timeIntervalSince1970
    }
    
    @objc private func onTTSStart() {
        print("[barge] onTTSStart")
        // Pause/stop recognition so the bot doesn't hear itself
        stopRecognition(.forTTS)
        
        // start VAD-only tap to detect your voice
        installBargeInTap()
    }
    
    private func installBargeInTap() {
        guard !bargeTapInstalled else { return }
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.removeTap(onBus: 0) // make sure bus is clean
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.detectBarge(in: buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
        bargeTapInstalled = true
        bargeStartTime = 0
    }

    private func removeBargeInTap() {
        guard bargeTapInstalled else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() } // we'll restart in startRecognition()
        bargeTapInstalled = false
        bargeStartTime = 0
    }
    
    private func detectBarge(in buffer: AVAudioPCMBuffer) {
        // Only meaningful if TTS is speaking
        guard TextToSpeechService.shared.isSpeaking else { return }
        guard let ch = buffer.floatChannelData?.pointee else { return }
        let n = Int(buffer.frameLength)
        if n == 0 { return }

        var sum: Float = 0
        for i in 0..<n { sum += ch[i] * ch[i] }
        let rms = sqrt(sum / Float(n))

        let now = CFAbsoluteTimeGetCurrent()
        // Log only when above gate to avoid spam
        if rms > bargeRMSGate {
            if bargeStartTime == 0 {
                bargeStartTime = CFAbsoluteTimeGetCurrent()
                print(String(format: "[barge] rms=%.4f > gate=%.4f — start hold", rms, bargeRMSGate))
            } else if CFAbsoluteTimeGetCurrent() - bargeStartTime > bargeHold {
                print("[barge] stop TTS (hold met)")
                bargeRequested = true
                TextToSpeechService.shared.stop() // will trigger .ttsDidFinish
                bargeStartTime = CFAbsoluteTimeGetCurrent()
            }
        } else if bargeStartTime != 0 {
            print("[barge] rms fell below gate — reset")
            bargeStartTime = 0
        }
    }
    
//    @objc private func handleInterruption(_ note: Notification) {
//        guard let info = note.userInfo,
//              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
//              let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
//
//        switch type {
//        case .began:
//            stopRecognition(.transient)
//            removeBargeInTap()
//        case .ended:
//            // resume only if we were in-session
//            guard isRecording else { return }
//            try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
//            startRecognition()
//        @unknown default: break
//        }
//    }
//
//    @objc private func handleRouteChange(_ note: Notification) {
//        // If route flips to an output-only profile (e.g., A2DP), rebuild engine
//        guard isRecording else { return }
//        removeBargeInTap()
//        stopRecognition(.transient)
//        startRecognition()
//    }



    @objc private func onTTSFinish() {
        print("[barge] onTTSFinish (bargeRequested=\(bargeRequested))")
        removeBargeInTap()
        // Resume listening for the next turn
        guard isRecording else { return }
        
        utteranceBuffer = ""
        transcribedText = ""
        
        // If we stopped TTS because user started speaking, resume faster
        let delay: TimeInterval = bargeRequested ? 0.05 : 0.25
        resumeGuardUntil = Date().timeIntervalSince1970 + delay
        bargeRequested = false
        suspendAutoRestart = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard self.isRecording else { return }
            self.startRecognition()
            self.lastVoiceTime = Date().timeIntervalSince1970
        }
    }
}
