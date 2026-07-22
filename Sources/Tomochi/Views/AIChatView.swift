import SwiftUI

struct AIChatView: View {
    @EnvironmentObject var chat: AIChatModel
    @State private var input = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("AI", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Picker("", selection: $chat.provider) {
                    ForEach(AIProviderKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
                Button {
                    chat.newConversation()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New conversation")
            }
            .padding(10)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if chat.messages.isEmpty {
                            Text("Ask the AI to manage your tasks:\n“Add ‘quarterly report’ to Work, due Friday”")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                        ForEach(chat.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        if chat.isRunning {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Working…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button("Stop") { chat.cancel() }
                                    .controlSize(.small)
                            }
                            .id("running")
                        }
                    }
                    .padding(10)
                }
                .onChange(of: chat.messages.count) {
                    withAnimation {
                        if let last = chat.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(alignment: .bottom) {
                TextField("Ask AI…", text: $input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(chat.isRunning || input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(10)
        }
        .onAppear { inputFocused = true }
    }

    private func send() {
        let text = input
        input = ""
        chat.send(text)
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 30)
                Text(message.text)
                    .padding(8)
                    .background(.blue.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
        case .assistant:
            HStack {
                Text(LocalizedStringKey(message.text))
                    .padding(8)
                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .textSelection(.enabled)
                Spacer(minLength: 30)
            }
        case .tool:
            Label(message.text, systemImage: "wrench.and.screwdriver")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .error:
            Label(message.text, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
    }
}
