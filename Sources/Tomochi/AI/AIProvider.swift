import Foundation

/// A pluggable CLI agent backend. Each provider knows how to build the
/// command line for a one-shot agentic run inside the workspace, and how to
/// parse its streaming JSONL output into chat events.
enum AIProviderKind: String, CaseIterable, Identifiable, Codable {
    case claude
    case codex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex (beta)"
        }
    }

    var executableName: String {
        switch self {
        case .claude: return "claude"
        case .codex: return "codex"
        }
    }

    /// Locates the executable in common install locations plus PATH.
    var executableURL: URL? {
        let fm = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/", "/usr/local/bin/", "/usr/bin/",
            NSHomeDirectory() + "/.local/bin/",
            NSHomeDirectory() + "/bin/",
        ].map { $0 + executableName }
        for path in candidates where fm.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        // Fall back to PATH lookup via /usr/bin/env at run time.
        return nil
    }

    var isInstalled: Bool {
        if executableURL != nil { return true }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        p.arguments = [executableName]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    /// Arguments for a non-interactive agentic run.
    /// `resumeToken` continues a previous conversation when supported.
    func arguments(prompt: String, resumeToken: String?) -> [String] {
        switch self {
        case .claude:
            var args = [
                "-p", prompt,
                "--output-format", "stream-json",
                "--verbose",
                "--permission-mode", "acceptEdits",
                "--allowedTools", "Read,Write,Edit,Glob,Grep",
            ]
            if let resumeToken {
                args += ["--resume", resumeToken]
            }
            return args
        case .codex:
            var args = ["exec", "--json", "--sandbox", "workspace-write"]
            if resumeToken != nil {
                // codex exec resume continues the most recent session.
                args = ["exec", "resume", "--last", "--json", "--sandbox", "workspace-write"]
            }
            args.append(prompt)
            return args
        }
    }
}

/// One parsed event from the provider's output stream.
enum AIStreamEvent {
    case sessionStarted(token: String)
    case assistantText(String)
    case toolUse(name: String, detail: String)
    case result(text: String, isError: Bool)
}

enum AIStreamParser {
    static func parse(line: String, provider: AIProviderKind) -> [AIStreamEvent] {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        switch provider {
        case .claude: return parseClaude(obj)
        case .codex: return parseCodex(obj)
        }
    }

    // claude -p --output-format stream-json emits one JSON object per line:
    //   {"type":"system","subtype":"init","session_id":...}
    //   {"type":"assistant","message":{"content":[{"type":"text"|"tool_use",...}]}}
    //   {"type":"result","subtype":"success","result":"..."}
    private static func parseClaude(_ obj: [String: Any]) -> [AIStreamEvent] {
        var events: [AIStreamEvent] = []
        switch obj["type"] as? String {
        case "system":
            if obj["subtype"] as? String == "init",
               let sessionId = obj["session_id"] as? String {
                events.append(.sessionStarted(token: sessionId))
            }
        case "assistant":
            guard let message = obj["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]]
            else { break }
            for block in content {
                switch block["type"] as? String {
                case "text":
                    if let text = block["text"] as? String, !text.isEmpty {
                        events.append(.assistantText(text))
                    }
                case "tool_use":
                    let name = block["name"] as? String ?? "Tool"
                    let input = block["input"] as? [String: Any] ?? [:]
                    let detail = (input["file_path"] as? String)
                        .map { URL(fileURLWithPath: $0).lastPathComponent }
                        ?? (input["pattern"] as? String)
                        ?? ""
                    events.append(.toolUse(name: name, detail: detail))
                default:
                    break
                }
            }
        case "result":
            let isError = (obj["is_error"] as? Bool) ?? ((obj["subtype"] as? String) != "success")
            let text = obj["result"] as? String ?? ""
            events.append(.result(text: text, isError: isError))
        default:
            break
        }
        return events
    }

    // codex exec --json emits JSONL; format has changed across versions, so
    // parse the two known shapes leniently.
    private static func parseCodex(_ obj: [String: Any]) -> [AIStreamEvent] {
        // Newer: {"type":"item.completed","item":{"type":"agent_message","text":"..."}}
        if obj["type"] as? String == "item.completed",
           let item = obj["item"] as? [String: Any] {
            switch item["type"] as? String {
            case "agent_message":
                if let text = item["text"] as? String {
                    return [.assistantText(text)]
                }
            case "command_execution":
                let cmd = item["command"] as? String ?? ""
                return [.toolUse(name: "Command", detail: cmd)]
            case "file_change", "patch_apply":
                return [.toolUse(name: "Edit", detail: "")]
            default:
                break
            }
        }
        // Older: {"msg":{"type":"agent_message","message":"..."}}
        if let msg = obj["msg"] as? [String: Any] {
            if msg["type"] as? String == "agent_message",
               let text = msg["message"] as? String {
                return [.assistantText(text)]
            }
        }
        return []
    }
}
