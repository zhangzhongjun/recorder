import ScreenCaptureKit
import CoreMedia
import CoreGraphics
import AppKit

@MainActor
class AudioCaptureManager: NSObject, ObservableObject {
    private var stream: SCStream?
    private let speechManager: SpeechManager
    private let store: TranscriptionStore

    init(speechManager: SpeechManager, store: TranscriptionStore) {
        self.speechManager = speechManager
        self.store = store
        super.init()
    }

    func startCapture() async throws {
        store.needsPermissionRetry = false
        store.needsRelaunch = false

        // ── Step 1: Check permission via CoreGraphics TCC API ──────────────────
        // CGPreflightScreenCaptureAccess() reads TCC live, no restart needed.
        if !CGPreflightScreenCaptureAccess() {
            // Show the system permission dialog (no-op if user previously denied via dialog)
            CGRequestScreenCaptureAccess()
            // Give TCC a moment to update after the dialog
            try await Task.sleep(nanoseconds: 300_000_000)

            if !CGPreflightScreenCaptureAccess() {
                // Still denied — send user to System Settings
                store.status = "请在系统设置中授予屏幕录制权限"
                store.needsPermissionRetry = true
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                )
                throw CaptureError.permissionDenied
            }
        }

        // ── Step 2: TCC says granted — get shareable content via ScreenCaptureKit ──
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            // SCKit can still fail on the very first launch after TCC grant until process restarts.
            store.status = "权限已授予，需重启应用生效"
            store.needsRelaunch = true
            throw CaptureError.needsRestart
        }

        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        // ── Step 3: Configure and start the stream ─────────────────────────────
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 16000
        config.channelCount = 1
        // ScreenCaptureKit requires a video format even for audio-only streams
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.showsCursor = false

        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )

        stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream?.addStreamOutput(
            self, type: .audio,
            sampleHandlerQueue: DispatchQueue.global(qos: .userInteractive)
        )
        try await stream?.startCapture()
    }

    func stopCapture() async {
        try? await stream?.stopCapture()
        stream = nil
    }
}

// MARK: - SCStreamOutput
extension AudioCaptureManager: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        Task { @MainActor in
            self.speechManager.appendAudioBuffer(sampleBuffer)
        }
    }
}

// MARK: - SCStreamDelegate
extension AudioCaptureManager: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            let nsError = error as NSError
            if nsError.code != -3817 { // -3817 = intentional stop
                self.store.status = "音频流错误: \(error.localizedDescription)"
                self.store.isRecording = false
            }
        }
    }
}

enum CaptureError: LocalizedError {
    case permissionDenied
    case needsRestart
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "屏幕录制权限未授权"
        case .needsRestart:     return "需要重启应用"
        case .noDisplay:        return "未找到显示器"
        }
    }
}
