import Foundation
import Combine
import FoundationModels

@MainActor
final class ChatEngine: ObservableObject {
    @Published private(set) var isGenerating = false
    @Published var errorMessage: String?

    private var generationTask: Task<Void, Never>?

    func send(_ rawText: String, store: ChatStore) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isGenerating, !text.isEmpty, text.count <= 2_000,
              SystemLanguageModel.default.isAvailable,
              let chatID = store.selectedID else { return }

        let context = makePrompt(history: store.messages(in: chatID), latest: text)
        store.append(ChatMessage(role: .user, text: text), to: chatID)
        let reply = ChatMessage(role: .assistant, text: "")
        store.append(reply, to: chatID)
        isGenerating = true
        errorMessage = nil

        generationTask = Task {
            defer {
                store.save()
                isGenerating = false
                generationTask = nil
            }
            do {
                try await stream(context, store: store, chatID: chatID, replyID: reply.id)
            } catch is CancellationError {
                if store.messages(in: chatID).first(where: { $0.id == reply.id })?.text.isEmpty == true {
                    store.remove(reply.id, from: chatID)
                }
            } catch LanguageModelError.contextSizeExceeded {
                // Fallback to the latest message when the model context is too long.
                do {
                    try await stream(text, store: store, chatID: chatID, replyID: reply.id)
                } catch {
                    handleError(error, store: store, chatID: chatID, replyID: reply.id)
                }
            } catch {
                handleError(error, store: store, chatID: chatID, replyID: reply.id)
            }
        }
    }

    func stop() {
        generationTask?.cancel()
    }

    private func stream(_ prompt: String, store: ChatStore, chatID: UUID, replyID: UUID) async throws {
        let session = LanguageModelSession(instructions: """
            You are PocketChat, a helpful and clear assistant running privately on an iPhone.
            Respond to the latest user message using recent conversation only as background.
            Be accurate, admit uncertainty, and do not invent sources.
            You have no internet, external tools, or live information.
            """)
        for try await snapshot in session.streamResponse(to: prompt) {
            try Task.checkCancellation()
            store.update(replyID, in: chatID, text: snapshot.content)
        }
    }

    private func handleError(_ error: Error, store: ChatStore, chatID: UUID, replyID: UUID) {
        if Task.isCancelled || error is CancellationError { return }
        if store.messages(in: chatID).first(where: { $0.id == replyID })?.text.isEmpty == true {
            store.remove(replyID, from: chatID)
        }
        errorMessage = "The on-device model couldn't finish. \(error.localizedDescription)"
    }

    private func makePrompt(history: [ChatMessage], latest: String) -> String {
        // Character-bound approximation leaves room for instructions and reply.
        var lines: [String] = []
        var remaining = 2_600
        for message in history.suffix(10).reversed() {
            guard !message.text.isEmpty else { continue }
            let text = String(message.text.suffix(800))
            let line = "\(message.role == .user ? "User" : "Assistant"): \(text)"
            guard line.count <= remaining else { break }
            lines.insert(line, at: 0)
            remaining -= line.count
        }
        guard !lines.isEmpty else { return latest }
        return "Recent conversation:\n\(lines.joined(separator: "\n\n"))\n\nLatest user message:\n\(latest)"
    }
}
