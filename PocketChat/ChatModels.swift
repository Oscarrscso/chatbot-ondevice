import Foundation

enum MessageRole: String, Codable {
    case user, assistant
}

struct ChatMessage: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var role: MessageRole
    var text: String
    var createdAt: Date = Date()
}

struct Conversation: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String = "New chat"
    var messages: [ChatMessage] = []
    var updatedAt: Date = Date()
}
