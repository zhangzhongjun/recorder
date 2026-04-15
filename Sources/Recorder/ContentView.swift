import SwiftUI

struct ContentView: View {
    @ObservedObject var store: TranscriptionStore
    @ObservedObject var viewModel: RecorderViewModel

    private var hasAI: Bool { ConfigManager.apiKey != nil }

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            transcriptionArea
            if hasAI && store.showAIPanel {
                aiPanel
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(store.isRecording ? Color.red : Color.gray)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(store.isRecording ? Color.red.opacity(0.4) : Color.clear)
                        .frame(width: 14, height: 14)
                        .scaleEffect(store.isRecording ? 1 : 0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                   value: store.isRecording)
                )

            Text(store.status)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)

            Spacer()

            if store.needsPermissionRetry {
                Button(action: { viewModel.retryAfterPermission() }) {
                    permissionBadge(label: "已授权，重试", icon: "checkmark.shield", color: .green)
                }
                .buttonStyle(.plain)
            }

            if store.needsRelaunch {
                Button(action: { viewModel.relaunch() }) {
                    permissionBadge(label: "重启应用", icon: "arrow.clockwise", color: .yellow)
                }
                .buttonStyle(.plain)
            }

            Picker("", selection: Binding(
                get: { store.selectedLanguage },
                set: { viewModel.changeLanguage($0) }
            )) {
                ForEach(RecognitionLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 70)
            .scaleEffect(0.85)
            .colorScheme(.dark)

            if hasAI {
                Button(action: { store.showAIPanel.toggle() }) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(store.showAIPanel ? .yellow.opacity(0.9) : .white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .help(store.showAIPanel ? "隐藏 AI 面板" : "显示 AI 面板")
            }

            Button(action: { store.clear() }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            Button(action: { viewModel.toggleRecording() }) {
                HStack(spacing: 4) {
                    Image(systemName: store.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(store.isRecording ? "停止" : "开始")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(store.isRecording ? Color.red.opacity(0.8) : Color.blue.opacity(0.8))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .overlay(alignment: .bottom) { Divider().opacity(0.3) }
    }

    @ViewBuilder
    private func permissionBadge(label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(label).font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.black)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 5).fill(color))
    }

    // MARK: - Transcription Area

    private var transcriptionArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(store.segments.enumerated()), id: \.element.id) { index, segment in
                        let distanceFromEnd = store.segments.count - 1 - index
                        SegmentView(segment: segment, distanceFromEnd: distanceFromEnd)
                            .id(segment.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .onChange(of: store.scrollTrigger) { _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    // MARK: - AI Panel

    private var aiPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Color.yellow.opacity(0.25)).frame(height: 1)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.yellow.opacity(0.8))
                Text("AI")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow.opacity(0.8))
                if store.isAIProcessing {
                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 7)
            .padding(.bottom, 4)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if let response = store.aiResponse {
                        AIResponseView(text: response)
                    } else if !store.isAIProcessing {
                        Text("等待识别内容...")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.25))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 80)
        }
        .background(Color.white.opacity(0.04))
    }
}

// MARK: - SegmentView

struct SegmentView: View {
    let segment: TranscriptionSegment
    let distanceFromEnd: Int

    private var opacity: Double {
        guard segment.isFinal else { return 0.55 }
        return 1.0 - Double(max(0, min(4, distanceFromEnd))) * 0.175
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(timeString(segment.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
                .frame(width: 38, alignment: .trailing)
                .padding(.top, distanceFromEnd == 0 ? 2 : 1)

            Text(segment.text)
                .font(.system(size: distanceFromEnd == 0 ? 17 : 15,
                              weight: distanceFromEnd == 0 ? .semibold : .regular))
                .foregroundColor(.white.opacity(opacity))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.easeOut(duration: 0.15), value: distanceFromEnd)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - AIResponseView

struct AIResponseView: View {
    let text: String

    var body: some View {
        if text.hasPrefix("Q:") {
            VStack(alignment: .leading, spacing: 4) {
                let lines = text.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                    if idx == 0 {
                        Text(line).font(.system(size: 12, weight: .semibold)).foregroundColor(.yellow.opacity(0.9))
                    } else {
                        Text(line).font(.system(size: 12)).foregroundColor(.white.opacity(0.85))
                    }
                }
            }
        } else {
            Text(text).font(.system(size: 12)).foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let store = TranscriptionStore()
        store.segments = [
            TranscriptionSegment(text: "Can you walk me through your experience?", isFinal: true),
            TranscriptionSegment(text: "Sure, I've been working on distributed systems for five years.", isFinal: true),
            TranscriptionSegment(text: "正在识别中...", isFinal: false),
        ]
        return ContentView(store: store, viewModel: RecorderViewModel(store: store))
            .frame(width: 500, height: 280)
    }
}
