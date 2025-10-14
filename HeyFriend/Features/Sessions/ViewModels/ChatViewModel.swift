//
//  ChatViewModel.swift
//  HeyFriend
//
//  Created by Denis Tatar 2 on 8/8/25.
//

import Foundation
import AVFoundation
import Speech
import Combine


class ChatViewModel: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var transcribedText: String = ""
    @Published var isRecording = false
    @Published var aiResponse: String = ""
    @Published var isTTSSpeaking = false
    // Loading
    @Published var isBootingSession = false
    @Published var isWaitingForReply = true

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
    
    // at top with other @Published
    @Published var rmsLevel: CGFloat = 0 // 0...1

    // add a smoother
    private var smoothed: CGFloat = 0
    private let smoothAlpha: CGFloat = 0.25


    // Barge-in monitor
    private var bargeTapInstalled = false
    private var bargeStartTime: CFTimeInterval = 0
    private var bargeRequested = false
    private var bargeRMSGate: Float { max(0.015, vadAmplitudeGate * 1.2) } // adaptive
    private let bargeHold: TimeInterval = 0.12 // ~120ms of voice to trigger

    // Summaries
    @Published var currentSummary: SessionSummary?
    @Published var isGeneratingSummary = false
    @Published var summaryError: String?
    
    // Adding TTS level to monitor assistant's expression to make orb movement match
    @Published var ttsLevel: CGFloat = 0   // 0..1 assistant loudness

    // Firestore session + transcript we persist
    @Published var currentSessionId: String?
    private var transcriptLines: [String] = []
    
    // ---- Session limit UI/state ----
    @Published var showTMinusFiveBanner = false
    @Published var showFinalCountdown = false
    @Published var finalCountdownSeconds = 0

    @Published var showSummarySheet = false          // summary modal you’ll show
    @Published var sessionEndedByTimeLimit = false   // hard stop guard

    private var hasIssuedWarning = false
    private var timerService: SessionTimerService?
    private var cancellables = Set<AnyCancellable>()
    private var sessionStartedAtLocal: Date?
    


    
    override init() {
        super.init()
        speechRecognizer.delegate = self
        requestPermissions()

        NotificationCenter.default.addObserver(self, selector: #selector(onTTSStart),
                                               name: .ttsDidStart, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onTTSFinish),
                                               name: .ttsDidFinish, object: nil)
        NotificationCenter.default.addObserver(forName: .ttsOutputLevel, object: nil, queue: .main) { [weak self] note in
            if let lvl = note.userInfo?["level"] as? CGFloat {
                self?.ttsLevel = lvl
            }
        }

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
        isBootingSession = true

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
        
        // 🔽 NEW: open a Firestore session + reset transcript
        Task {
            do {
                guard let uid = AuthService.shared.userId else {
                    print("No signed-in user; cannot start session.")
                    await MainActor.run { self.isBootingSession = false }
                    return
                }

                // Create Firestore session and capture sid FIRST
                let sid = try await FirestoreService.shared.startSession(uid: uid)

                // Publish id to the UI immediately
                await MainActor.run {
                    self.currentSessionId = sid
                    self.transcriptLines.removeAll()
                }
                
                // Reset time-limit UI/flags at the start of each session
                hasIssuedWarning = false
                showTMinusFiveBanner = false
                showFinalCountdown = false
                finalCountdownSeconds = 0
                sessionEndedByTimeLimit = false


                // Seed start time and attach a short test timer (60s). Flip to 30*60 for prod.
                let startedLocal = Date()
                self.sessionStartedAtLocal = startedLocal

                if EntitlementSync.shared.isPlus {
                    
                    // MARK: - Test vr. Prod Timmer
                    // 25 minutes, w/ 15 minute warning
                    let maxSeconds = 20 * 60        // Max amount to chat = 20 minutes
//                    let warnThreshold = 300
                    let warnThreshold = 15 * 60     // Show warning at 15 minutes
                    self.timerService = SessionTimerService(
                        startedAt: startedLocal,
                        maxDuration: TimeInterval(maxSeconds),
                        warnAtSeconds: TimeInterval(warnThreshold)
                    )
                    
                    // Testing
                    // 60 seconds, w/ 10 seconds warning
//                    let maxSeconds = 60
//                    let warnThreshold = 10
//                    self.timerService = SessionTimerService(
//                        startedAt: startedLocal,
//                        maxDuration: 60,
//                        warnAtSeconds: 10
//                    )

                    self.timerService?.publisher
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] state in
                            guard let self else { return }

                            // ⏰ One-time warning + auto-dismiss
                            // TEST: warn at 5 mins remaining; PROD: change to 15 * 60 (15 minutes)
                            let warnThreshold = 15 * 60  // warning
                            if !self.hasIssuedWarning, Int(state.remaining) <= warnThreshold {
                                self.hasIssuedWarning = true
                                self.showTMinusFiveBanner = true

                                // (Optional) persist a "warningIssuedAt" in Firestore if you want
                                if let uid = AuthService.shared.userId, let sid = self.currentSessionId {
                                    Task { await FirestoreService.shared.markSessionWarning(uid: uid, sid: sid) }
                                }
                            }

                            // Keep banner visible and keep updating the countdown until 0
                            let rem = Int(ceil(state.remaining))
                            self.finalCountdownSeconds = max(0, rem) // always update
                            self.showFinalCountdown = rem <= 60      // switch to numeric countdown in last minute

                            // Hard stop
                            if state.isOverLimit {
                                self.endDueToTimeLimit()
                            }
                        }
                        .store(in: &self.cancellables)

                    // Keep Firestore in sync with the cap (use 1800 for prod)
                    if let uid = AuthService.shared.userId, let sid = self.currentSessionId {
                        Task { await FirestoreService.shared.setMaxDuration(uid: uid, sid: sid, seconds: maxSeconds) }
                    }
                }

                await MainActor.run { self.isBootingSession = false }
            } catch {
                print("Failed to start Firestore session:", error)
                await MainActor.run { self.isBootingSession = false }
            }
        }
    }
    
    // Use of session limit
    private func endDueToTimeLimit() {
        // 1) UI resets FIRST so nothing lingers
        showTMinusFiveBanner = false
        showFinalCountdown = false
        finalCountdownSeconds = 0

        // 2) Hard-stop guards
        sessionEndedByTimeLimit = true
        isRecording = false

        // 3) Stop audio/streams/timer
        stopRecognition(.userStop)
        TextToSpeechService.shared.stop()
        timerService?.stop()
        timerService = nil

        // 4) Persist end state
        if let uid = AuthService.shared.userId, let sid = currentSessionId {
            Task { await FirestoreService.shared.endSessionByTimeLimit(uid: uid, sid: sid) }
        }

        // 5) Auto-start summary + show sheet
        endSessionAndSummarize()
        showSummarySheet = true
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

        // existing VAD logic…
        if rms > vadAmplitudeGate {
            lastVoiceTime = Date().timeIntervalSince1970
            if TextToSpeechService.shared.isSpeaking {
                TextToSpeechService.shared.stop()
                resumeGuardUntil = Date().timeIntervalSince1970 + 0.20
            }
        }

        // NEW: normalize + smooth for the orb
        let noiseFloor: Float = 0.005
        let gain: Float = 18.0
        let raw = max(0, min(1, (rms - noiseFloor) * gain))
        let target = CGFloat(raw)
        smoothed = smoothed + smoothAlpha * (target - smoothed)

        DispatchQueue.main.async {
            self.rmsLevel = self.smoothed
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

         // 🔽 NEW: record the user turn, persist transcript
        appendAndPersist(role: "You", text: userTurn)
        
        // User is waiting for a reply
        isWaitingForReply = true

        ChatService.shared.sendMessage(userTurn) { reply in
            DispatchQueue.main.async {
                // ⛔️ If session ended by time limit, ignore late replies completely
                guard !self.sessionEndedByTimeLimit else { return }
                
                let bot = (reply ?? "Sorry, I didn’t catch that. Can you try again?").trimmingCharacters(in: .whitespacesAndNewlines)
                self.aiResponse = bot
                // 🔽 NEW: record assistant turn, persist transcript
                self.appendAndPersist(role: "HeyFriend", text: bot)

                TextToSpeechService.shared.speak(bot)
                // After TTS finishes, onTTSFinish() will bring us back to listening
            }
        }

        // Prepare for next turn
        utteranceBuffer = ""
        lastVoiceTime = Date().timeIntervalSince1970
    }
    
    // Send a pre-selected user turn (from SessionsHomeView) as if the user spoke it.
    func seedAndQuery(_ userTurn: String) {
        let text = userTurn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Avoid the mic hearing the bot while we inject the turn
        stopRecognition(.forTTS)

        // Record + persist just like a normal committed utterance
        appendAndPersist(role: "You", text: text)
        
        // User is waiting for reply
        isWaitingForReply = true

        ChatService.shared.sendMessage(text) { reply in
            DispatchQueue.main.async {
                let bot = (reply ?? "Sorry, I didn’t catch that. Can you try again?")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                self.aiResponse = bot
                self.appendAndPersist(role: "HeyFriend", text: bot)

                TextToSpeechService.shared.speak(bot)
                // onTTSFinish() will resume listening (your existing flow)
            }
        }

        // Prep for next live turn
        utteranceBuffer = ""
        lastVoiceTime = Date().timeIntervalSince1970
    }

    
    private func appendAndPersist(role: String, text: String) {
        transcriptLines.append("\(role): \(text)")
        guard let uid = AuthService.shared.userId, let sid = currentSessionId else { return }
        let full = transcriptLines.joined(separator: "\n")
        Task {
            try? await FirestoreService.shared.updateTranscript(uid: uid, sid: sid, transcript: full)
        }
    }

    
    @objc private func onTTSStart() {
        isTTSSpeaking = true
        isWaitingForReply = false   // ✅ stop the spinner now that reply is speaking
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
        isTTSSpeaking = false
        isWaitingForReply = false   // ensuring our reply message to user doesn't show more than once!
        print("[barge] onTTSFinish (bargeRequested=\(bargeRequested))")
        removeBargeInTap()
        
        // ⛔️ If we hit the time limit, do not resume listening
        guard !sessionEndedByTimeLimit else { return }
        
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
    
    // Summary generation call
    func endSessionAndSummarize() {
        isGeneratingSummary = true
        summaryError = nil

        // Build transcript from the local lines we saved (same format you used)
        let transcript = transcriptLines.joined(separator: "\n")
        
//        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
//            isGeneratingSummary = false
//            summaryError = "No conversation to summarize."
//            return
//        }

        // Safety: capture session id now
        guard let sid = currentSessionId, let uid = AuthService.shared.userId else {
            isGeneratingSummary = false
            summaryError = "No session to summarize."
            return
        }

        print("=== Conversation Transcript ===\n\(transcript)\n=== End Transcript ===")

        ChatService.shared.generateSummary(sessionId: sid, transcript: transcript) { summary in
            DispatchQueue.main.async {
                self.isGeneratingSummary = false
                guard let mapped = summary else {
                    self.summaryError = "Failed to generate summary."
                    return
                }
                self.currentSummary = mapped

                // 🔽 Persist summary bundle to Firestore
                Task {
                    // You likely have a better duration source; placeholder 0 here:
                    try? await FirestoreService.shared.writeSummaryBundle(
                        uid: uid,
                        sid: sid,
                        durationSec: 0,
                        mapped: mapped
                    )
                    // Clear active session
                    await MainActor.run { self.currentSessionId = nil }
                }
            }
        }
    }

    
    
    
}
