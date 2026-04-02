import Foundation
import Combine

struct TranscriptionSegment: Identifiable {
    let id = UUID()
    var text: String
    let timestamp: Date
    var isFinal: Bool

    init(text: String, isFinal: Bool) {
        self.text = text
        self.timestamp = Date()
        self.isFinal = isFinal
    }
}

@MainActor
class TranscriptionStore: ObservableObject {
    @Published var segments: [TranscriptionSegment] = []
    @Published var isRecording: Bool = false
    @Published var status: String = "就绪"
    @Published var selectedLanguage: RecognitionLanguage = .english
    @Published var scrollTrigger: Int = 0
    // Permission UI states — mutually exclusive
    @Published var needsPermissionRetry: Bool = false  // granted in settings, can retry without restart
    @Published var needsRelaunch: Bool = false          // SCKit still fails after grant; restart required

    private let maxSegments = 100

    func appendFinal(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Replace last partial segment or add new
        if let lastIndex = segments.indices.last, !segments[lastIndex].isFinal {
            segments[lastIndex].text = trimmed
            segments[lastIndex].isFinal = true
        } else {
            segments.append(TranscriptionSegment(text: trimmed, isFinal: true))
        }

        if segments.count > maxSegments {
            segments.removeFirst(segments.count - maxSegments)
        }
        scrollTrigger += 1
    }

    func updatePartial(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let lastIndex = segments.indices.last, !segments[lastIndex].isFinal {
            segments[lastIndex].text = trimmed
        } else {
            segments.append(TranscriptionSegment(text: trimmed, isFinal: false))
        }
        scrollTrigger += 1
    }

    func clear() {
        segments = []
    }
}

enum RecognitionLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-CN"
    case english = "en-US"
    case auto = "auto"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        case .auto: return "自动"
        }
    }

    var localeIdentifiers: [String] {
        switch self {
        case .chinese: return ["zh-CN", "zh-TW", "zh-HK"]
        case .english: return ["en-US", "en-GB"]
        case .auto: return ["zh-CN", "en-US"]
        }
    }
}
