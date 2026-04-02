import Speech
import AVFoundation
import CoreMedia

@MainActor
class SpeechManager: NSObject, ObservableObject {
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private let store: TranscriptionStore
    private var restartTimer: Timer?
    private var silenceTimer: Timer?
    private var lastResultText: String = ""
    private var sessionStartTime: Date?

    // Apple Speech has ~1 min limit per task; restart before that
    private let taskDurationLimit: TimeInterval = 50
    private let silenceTimeout: TimeInterval = 2.5

    init(store: TranscriptionStore) {
        self.store = store
        super.init()
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func start(language: RecognitionLanguage) {
        stop()
        lastResultText = ""
        startSession(language: language)

        restartTimer = Timer.scheduledTimer(withTimeInterval: taskDurationLimit, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.cycleSession(language: language)
            }
        }
    }

    func stop() {
        restartTimer?.invalidate()
        restartTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        endSession(finalize: true)
    }

    func appendAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        recognitionRequest?.appendAudioSampleBuffer(sampleBuffer)
        resetSilenceTimer()
    }

    // MARK: - Private

    private func startSession(language: RecognitionLanguage) {
        let locale = Locale(identifier: language.localeIdentifiers.first ?? "zh-CN")
        recognizer = SFSpeechRecognizer(locale: locale)
        recognizer?.defaultTaskHint = .dictation

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        // Enable punctuation on supported OS versions
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }

        recognitionRequest = request
        sessionStartTime = Date()

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.store.appendFinal(text)
                        self.lastResultText = ""
                    } else {
                        self.store.updatePartial(text)
                        self.lastResultText = text
                    }
                }
                if let error = error {
                    let nsError = error as NSError
                    // Code 301 = recognition canceled (normal on restart)
                    // Code 203 = no speech detected
                    let ignoredCodes = [301, 203, 1101, 1107, 1110]
                    if !ignoredCodes.contains(nsError.code) {
                        self.store.status = "识别错误: \(nsError.localizedDescription)"
                    }
                }
            }
        }
    }

    private func endSession(finalize: Bool) {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        recognizer = nil

        if finalize && !lastResultText.isEmpty {
            store.appendFinal(lastResultText)
            lastResultText = ""
        }
    }

    private func cycleSession(language: RecognitionLanguage) {
        endSession(finalize: true)
        startSession(language: language)
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                // Commit current partial on silence
                if !self.lastResultText.isEmpty {
                    self.store.appendFinal(self.lastResultText)
                    self.lastResultText = ""
                    // Restart session to get fresh context
                    self.cycleSession(language: self.store.selectedLanguage)
                }
            }
        }
    }
}
