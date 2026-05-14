import Foundation

@MainActor
class NotesStore: ObservableObject {
    @Published var text: String = ""
    @Published var showPanel: Bool = false
    private let filePath: URL
    private var saveTask: Task<Void, Never>?

    init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/recorder")
        filePath = dir.appendingPathComponent("notes.txt")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        text = (try? String(contentsOf: filePath, encoding: .utf8)) ?? ""
    }

    func save() {
        saveTask?.cancel()
        let snapshot = text
        let path = filePath
        saveTask = Task.detached(priority: .background) {
            try? snapshot.write(to: path, atomically: true, encoding: .utf8)
        }
    }

    func clear() {
        text = ""
        save()
    }
}
