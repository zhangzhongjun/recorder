import Foundation
import AppKit

@MainActor
class RecorderViewModel: ObservableObject {
    let store: TranscriptionStore
    private let speechManager: SpeechManager
    private let captureManager: AudioCaptureManager

    init(store: TranscriptionStore) {
        self.store = store
        self.speechManager = SpeechManager(store: store)
        self.captureManager = AudioCaptureManager(speechManager: speechManager, store: store)
    }

    func toggleRecording() {
        if store.isRecording {
            stopRecording()
        } else {
            Task { await startRecording() }
        }
    }

    // Called by the "重试" button — no restart needed, TCC was updated
    func retryAfterPermission() {
        Task { await startRecording() }
    }

    // Called by the "重启" button — uses /usr/bin/open so the new instance
    // starts before this process terminates
    func relaunch() {
        let bundlePath = Bundle.main.bundleURL.path
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundlePath]   // -n forces a new instance
        try? task.run()
        // Give /usr/bin/open 0.5 s to spawn the new process, then quit
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
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
            store.isRecording = true
            store.status = "正在监听..."
        } catch {
            speechManager.stop()
            // needsPermissionRetry / needsRelaunch / status already set inside startCapture
        }
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
