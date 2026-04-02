import SwiftUI

struct ContentView: View {
    @ObservedObject var store: TranscriptionStore
    @ObservedObject var viewModel: RecorderViewModel
    @State private var isHoveringControls = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            transcriptionArea
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Control Bar
    private var controlBar: some View {
        HStack(spacing: 8) {
            // Recording indicator
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

            // Status text
            Text(store.status)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)

            Spacer()

            // "重试" — TCC says granted now, no restart needed
            if store.needsPermissionRetry {
                Button(action: { viewModel.retryAfterPermission() }) {
                    permissionBadge(label: "已授权，重试", icon: "checkmark.shield", color: .green)
                }
                .buttonStyle(.plain)
                .help("已在系统设置中授权屏幕录制，点击重试")
            }

            // "重启" — SCKit still failing after TCC grant; process restart required
            if store.needsRelaunch {
                Button(action: { viewModel.relaunch() }) {
                    permissionBadge(label: "重启应用", icon: "arrow.clockwise", color: .yellow)
                }
                .buttonStyle(.plain)
                .help("权限已授予，但需重启应用才能生效")
            }

            // Language picker
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

            // Clear button
            Button(action: { store.clear() }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("清空字幕")

            // Start/Stop button
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
        .overlay(alignment: .bottom) {
            Divider().opacity(0.3)
        }
    }

    @ViewBuilder
    private func permissionBadge(label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
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

                    // Spacer at bottom for auto-scroll target
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .onChange(of: store.scrollTrigger) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

struct SegmentView: View {
    let segment: TranscriptionSegment
    let distanceFromEnd: Int  // 0 = latest

    // Opacity fades from 1.0 (latest) down to 0.25 (older than 4 lines)
    private var opacity: Double {
        guard segment.isFinal else { return 0.55 }  // partial result
        let fade = max(0, min(4, distanceFromEnd))
        return 1.0 - Double(fade) * 0.175
    }

    private var fontSize: CGFloat {
        distanceFromEnd == 0 ? 17 : 15
    }

    private var fontWeight: Font.Weight {
        distanceFromEnd == 0 ? .semibold : .regular
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(timeString(segment.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
                .frame(width: 42, alignment: .trailing)
                .padding(.top, distanceFromEnd == 0 ? 3 : 2)

            Text(segment.text)
                .font(.system(size: fontSize, weight: fontWeight))
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let store = TranscriptionStore()
        store.segments = [
            TranscriptionSegment(text: "大家好，我们开始今天的会议", isFinal: true),
            TranscriptionSegment(text: "首先来看一下上周的进展", isFinal: true),
            TranscriptionSegment(text: "正在识别中...", isFinal: false),
        ]
        let vm = RecorderViewModel(store: store)
        return ContentView(store: store, viewModel: vm)

            .frame(width: 600, height: 300)
    }
}
