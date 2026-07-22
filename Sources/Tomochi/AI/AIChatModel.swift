import Foundation
import Combine

/// Thread-safe accumulation of subprocess output across pipe callbacks.
final class StreamBuffers: @unchecked Sendable {
    private let lock = NSLock()
    private var lineBuffer = ""
    private var stderrData = Data()

    func appendAndExtractLines(_ chunk: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        lineBuffer += chunk
        var lines: [String] = []
        while let range = lineBuffer.range(of: "\n") {
            lines.append(String(lineBuffer[..<range.lowerBound]))
            lineBuffer.removeSubrange(..<range.upperBound)
        }
        return lines
    }

    func appendStderr(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        stderrData.append(data)
    }

    func stderrText() -> String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: stderrData, encoding: .utf8) ?? ""
    }
}

struct ChatMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user
        case assistant
        case tool
        case error
    }

    let id = UUID()
    var role: Role
    var text: String
}

/// Runs the selected CLI agent (claude / codex) as a subprocess inside the AI
/// workspace, streams its JSONL output into chat messages, and reloads the
/// data store when the run finishes.
@MainActor
final class AIChatModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isRunning = false
    @Published var provider: AIProviderKind {
        didSet {
            UserDefaults.standard.set(provider.rawValue, forKey: "aiProvider")
            resumeToken = nil
        }
    }

    private var process: Process?
    private var resumeToken: String?
    private weak var store: DataStore?

    init(store: DataStore) {
        self.store = store
        let saved = UserDefaults.standard.string(forKey: "aiProvider")
        provider = saved.flatMap(AIProviderKind.init(rawValue:)) ?? .claude
    }

    func newConversation() {
        cancel()
        messages = []
        resumeToken = nil
    }

    func cancel() {
        process?.terminate()
        process = nil
        isRunning = false
    }

    func send(_ prompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isRunning else { return }
        messages.append(ChatMessage(role: .user, text: trimmed))
        isRunning = true
        runProcess(prompt: trimmed)
    }

    private func runProcess(prompt: String) {
        let provider = self.provider
        let p = Process()
        if let url = provider.executableURL {
            p.executableURL = url
            p.arguments = provider.arguments(prompt: prompt, resumeToken: resumeToken)
        } else {
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = [provider.executableName]
                + provider.arguments(prompt: prompt, resumeToken: resumeToken)
        }
        p.currentDirectoryURL = Paths.workspace

        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:" + NSHomeDirectory() + "/.local/bin"
        env["PATH"] = extraPaths + ":" + (env["PATH"] ?? "/usr/bin:/bin")
        p.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        p.standardOutput = stdout
        p.standardError = stderr
        p.standardInput = FileHandle.nullDevice

        let buffers = StreamBuffers()
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            let lines = buffers.appendAndExtractLines(chunk)
            guard !lines.isEmpty else { return }
            Task { @MainActor in
                for line in lines where !line.isEmpty {
                    self?.handle(events: AIStreamParser.parse(line: line, provider: provider))
                }
            }
        }

        stderr.fileHandleForReading.readabilityHandler = { handle in
            buffers.appendStderr(handle.availableData)
        }

        p.terminationHandler = { [weak self] proc in
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            let status = proc.terminationStatus
            let errText = buffers.stderrText()
            Task { @MainActor in
                self?.finish(status: status, stderr: errText)
            }
        }

        do {
            try p.run()
            process = p
        } catch {
            messages.append(ChatMessage(
                role: .error,
                text: "Failed to launch \(provider.executableName): \(error.localizedDescription)\nMake sure the \(provider.displayName) CLI is installed."
            ))
            isRunning = false
        }
    }

    private func handle(events: [AIStreamEvent]) {
        for event in events {
            switch event {
            case .sessionStarted(let token):
                resumeToken = token
            case .assistantText(let text):
                messages.append(ChatMessage(role: .assistant, text: text))
            case .toolUse(let name, let detail):
                let suffix = detail.isEmpty ? "" : ":\(detail)"
                messages.append(ChatMessage(role: .tool, text: "\(name)\(suffix)"))
            case .result(let text, let isError):
                if isError {
                    let msg = text.isEmpty ? "The AI run failed" : text
                    messages.append(ChatMessage(role: .error, text: msg))
                }
                // Success text already arrived as the last assistant message.
            }
        }
        store?.reloadFromDisk()
    }

    private func finish(status: Int32, stderr: String) {
        isRunning = false
        process = nil
        if status != 0, messages.last?.role != .error {
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let hint = detail.isEmpty ? "exit code \(status)" : String(detail.suffix(500))
            messages.append(ChatMessage(role: .error, text: "AI run failed: \(hint)"))
        }
        store?.reloadFromDisk()
    }
}
