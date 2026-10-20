import SwiftUI
import FoundationModels
import UIKit

struct ChatView: View {
    @StateObject private var store = ChatStore()
    @StateObject private var engine = ChatEngine()
    @State private var draft = ""
    @State private var showingHistory = false
    @FocusState private var isFocused: Bool

    private var messages: [ChatMessage] { store.selectedConversation?.messages ?? [] }

    private var availabilityNote: String? {
        switch SystemLanguageModel.default.availability {
        case .available: return nil
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Enable Apple Intelligence in Settings to use the on-device chatbot."
        case .unavailable(.deviceNotEligible):
            return "This iPhone does not support the Apple Intelligence language model."
        case .unavailable(.modelNotReady):
            return "Apple's on-device model is not ready yet. Wait for it to finish downloading."
        @unknown default:
            return "The on-device model is currently unavailable."
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let availabilityNote {
                    Label(availabilityNote, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
                if messages.isEmpty { welcomeView }
                else { conversationView }
                composer
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(store.selectedConversation?.title ?? "PocketChat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isFocused = false
                        showingHistory = true
                    } label: { Image(systemName: "line.3.horizontal") }
                    .accessibilityLabel("Conversations")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        engine.stop()
                        store.newChat()
                        draft = ""
                        isFocused = false
                    } label: { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel("New chat")
                }
            }
            .sheet(isPresented: $showingHistory) {
                NavigationStack {
                    List {
                        Section("Saved on this iPhone") {
                            ForEach(store.conversations) { chat in
                                Button {
                                    engine.stop()
                                    store.select(chat.id)
                                    showingHistory = false
                                } label: {
                                    HStack {
                                        Image(systemName: "bubble.left")
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(chat.title).lineLimit(1)
                                            Text(chat.updatedAt, style: .date)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if store.selectedID == chat.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .swipeActions {
                                    Button("Delete", role: .destructive) {
                                        engine.stop()
                                        store.delete(chat.id)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Conversations")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { showingHistory = false }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                engine.stop()
                                store.newChat()
                                showingHistory = false
                            } label: { Image(systemName: "square.and.pencil") }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Chat error", isPresented: Binding(
                get: { engine.errorMessage != nil },
                set: { if !$0 { engine.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { engine.errorMessage = nil }
            } message: { Text(engine.errorMessage ?? "Unknown error") }
        }
    }

    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: 18) {
                Spacer(minLength: 54)
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                    .frame(width: 102, height: 102)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30))
                Text("Think locally.")
                    .font(.system(size: 33, weight: .semibold, design: .rounded))
                Text("Your private AI companion, powered by your iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Label("No account · No API fees · Offline", systemImage: "iphone")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(.regularMaterial, in: Capsule())
                ForEach(["Explain something complicated simply",
                         "Help me plan my day",
                         "Write me a short story",
                         "Brainstorm a creative idea"], id: \.self) { suggestion in
                    Button {
                        draft = suggestion
                        isFocused = true
                    } label: {
                        HStack {
                            Text(suggestion)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                        }
                        .font(.subheadline)
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var conversationView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(messages) { message in
                        if !message.text.isEmpty || (engine.isGenerating && message.id == messages.last?.id) {
                            HStack(alignment: .top, spacing: 8) {
                                if message.role == .user { Spacer(minLength: 48) }
                                if message.role == .assistant {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.tint)
                                        .frame(width: 28, height: 28)
                                }
                                Group {
                                    if message.text.isEmpty {
                                        HStack(spacing: 8) {
                                            ProgressView().controlSize(.small)
                                            Text("Thinking on-device…")
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text(message.text).textSelection(.enabled)
                                    }
                                }
                                .padding(14)
                                .background(
                                    message.role == .user
                                        ? Color.accentColor.opacity(0.15)
                                        : Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 20)
                                )
                                .contextMenu {
                                    if !message.text.isEmpty {
                                        Button("Copy", systemImage: "doc.on.doc") {
                                            UIPasteboard.general.string = message.text
                                        }
                                    }
                                }
                                if message.role == .assistant { Spacer(minLength: 12) }
                            }
                            .id(message.id)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.last?.text) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: messages.count) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask anything…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit(send)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                .accessibilityLabel("Message")
            if engine.isGenerating {
                Button { engine.stop() } label: {
                    Image(systemName: "stop.fill").frame(width: 44, height: 44)
                }
                .buttonStyle(.glassProminent)
                .accessibilityLabel("Stop")
            } else {
                Button(action: send) {
                    Image(systemName: "arrow.up").frame(width: 44, height: 44)
                }
                .buttonStyle(.glassProminent)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || draft.count > 2_000 || availabilityNote != nil)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func send() {
        guard !engine.isGenerating, availabilityNote == nil else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 2_000 else { return }
        draft = ""
        isFocused = false
        engine.send(text, store: store)
    }
}
