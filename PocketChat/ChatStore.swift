import Foundation
import Combine

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var selectedID: UUID?

    private let fileURL: URL

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PocketChat", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("chats.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Conversation].self, from: data) {
            conversations = saved.sorted { $0.updatedAt > $1.updatedAt }
        }
        if conversations.isEmpty { newChat() }
        else { selectedID = conversations.first?.id }
    }

    var selectedConversation: Conversation? {
        conversations.first { $0.id == selectedID }
    }

    func messages(in id: UUID) -> [ChatMessage] {
        conversations.first(where: { $0.id == id })?.messages ?? []
    }

    func newChat() {
        let chat = Conversation()
        conversations.insert(chat, at: 0)
        selectedID = chat.id
        save()
    }

    func select(_ id: UUID) {
        guard conversations.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }

    func delete(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        if conversations.isEmpty { newChat() }
        else if selectedID == id { selectedID = conversations.first?.id }
        save()
    }

    func append(_ message: ChatMessage, to chatID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == chatID }) else { return }
        conversations[index].messages.append(message)
        conversations[index].updatedAt = .now
        if message.role == .user, conversations[index].title == "New chat" {
            let firstLine = message.text.split(separator: "\n").first.map(String.init) ?? message.text
            conversations[index].title = String(firstLine.prefix(42))
        }
        save()
    }

    func update(_ messageID: UUID, in chatID: UUID, text: String) {
        guard let index = conversations.firstIndex(where: { $0.id == chatID }),
              let messageIndex = conversations[index].messages.firstIndex(where: { $0.id == messageID })
        else { return }
        conversations[index].messages[messageIndex].text = text
        conversations[index].updatedAt = .now
    }

    func remove(_ messageID: UUID, from chatID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == chatID }) else { return }
        conversations[index].messages.removeAll { $0.id == messageID }
        save()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
