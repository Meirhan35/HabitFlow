import Foundation
import Combine

@MainActor
public final class AssistantChatStore: ObservableObject {
    @Published public var chats: [AssistantChat] = [] {
        didSet { save() }
    }
    private let fileURL: URL

    public init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = base.appendingPathComponent("HabitFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("assistant_chats_v1.json")
        if let data = try? Data(contentsOf: fileURL), let saved = try? JSONDecoder().decode([AssistantChat].self, from: data) {
            chats = saved
        }
    }

    public func newChat() -> UUID {
        let chat = AssistantChat()
        chats.insert(chat, at: 0)
        return chat.id
    }

    public func update(_ chat: AssistantChat) {
        guard let index = chats.firstIndex(where: { $0.id == chat.id }) else { return }
        chats[index] = chat
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(chats) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
