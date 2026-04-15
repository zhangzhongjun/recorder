import Foundation
import AppKit

@MainActor
class RecorderViewModel: ObservableObject {
    let store: TranscriptionStore
    private let speechManager: SpeechManager
    private let captureManager: AudioCaptureManager
    let aiManager: AIManager

    init(store: TranscriptionStore) {
        self.store = store
        self.speechManager = SpeechManager(store: store)
        self.captureManager = AudioCaptureManager(speechManager: speechManager, store: store)
        self.aiManager = AIManager(store: store)

        store.onFinalAppended = { [weak aiManager] text in
            aiManager?.onNewSegment(text: text)
        }
    }

    func toggleRecording() {
        if store.isRecording { stopRecording() }
        else { Task { await startRecording() } }
    }

    func retryAfterPermission() {
        Task { await startRecording() }
    }

    func relaunch() {
        let bundlePath = Bundle.main.bundleURL.path
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundlePath]
        try? task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
    }

    private func startRecording() async {
        store.status = "请求权限..."
        store.needsPermissionRetry = false
        store.needsRelaunch = false

        let speechGranted = await speechManager.requestPermission()
        guard speechGranted else {
            store.status = "语音识别权限被拒绝，请在系统设置中授权"
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!
            )
            return
        }

        speechManager.start(language: store.selectedLanguage)

        do {
            try await captureManager.startCapture()
        } catch {
            speechManager.stop()
            return
        }

        store.isRecording = true
        store.status = "正在监听..."
    }

    private func stopRecording() {
        Task {
            await captureManager.stopCapture()
            speechManager.stop()
            store.isRecording = false
            store.status = "已停止"
        }
    }

    func changeLanguage(_ language: RecognitionLanguage) {
        store.selectedLanguage = language
        if store.isRecording {
            speechManager.stop()
            speechManager.start(language: language)
        }
    }
}
