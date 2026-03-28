import Foundation

actor JSONLParser {
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func parseAll(at basePath: String) async throws -> ([Project], [Session]) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: basePath) else {
            throw ParserError.directoryNotFound(basePath)
        }

        let contents = try fm.contentsOfDirectory(atPath: basePath)
        var projects: [Project] = []
        var allSessions: [Session] = []

        for dirName in contents {
            let dirPath = (basePath as NSString).appendingPathComponent(dirName)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dirPath, isDirectory: &isDir), isDir.boolValue else { continue }

            let displayName = Self.decodeProjectName(dirName)
            var project = Project(id: dirName, dirName: dirName, displayName: displayName, path: dirPath)

            let files = (try? fm.contentsOfDirectory(atPath: dirPath)) ?? []
            let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }

            for file in jsonlFiles {
                let sessionId = String(file.dropLast(6)) // remove .jsonl
                let filePath = (dirPath as NSString).appendingPathComponent(file)
                if let session = try? await parseSession(filePath: filePath, sessionId: sessionId, projectDirName: dirName, projectPath: displayName) {
                    project.sessions.append(session)
                    allSessions.append(session)
                }

                // Parse subagent files
                let subagentDir = (dirPath as NSString).appendingPathComponent("\(sessionId)/subagents")
                if fm.fileExists(atPath: subagentDir) {
                    let subFiles = (try? fm.contentsOfDirectory(atPath: subagentDir)) ?? []
                    for subFile in subFiles where subFile.hasSuffix(".jsonl") {
                        let subPath = (subagentDir as NSString).appendingPathComponent(subFile)
                        if var subSession = try? await parseSession(filePath: subPath, sessionId: "\(sessionId)/\(subFile)", projectDirName: dirName, projectPath: displayName) {
                            // Merge subagent usage into parent session
                            if let idx = project.sessions.firstIndex(where: { $0.id == sessionId }) {
                                project.sessions[idx].usage.add(subSession.usage)
                                for (model, modelUsage) in subSession.modelsUsed {
                                    var existing = project.sessions[idx].modelsUsed[model] ?? TokenUsage()
                                    existing.add(modelUsage)
                                    project.sessions[idx].modelsUsed[model] = existing
                                }
                            }
                        }
                    }
                }
            }

            if !project.sessions.isEmpty {
                projects.append(project)
            }
        }

        // Update allSessions from projects (with merged subagent data)
        allSessions = projects.flatMap(\.sessions)
        projects.sort { ($0.lastActive ?? .distantPast) > ($1.lastActive ?? .distantPast) }
        return (projects, allSessions)
    }

    private func parseSession(filePath: String, sessionId: String, projectDirName: String, projectPath: String) async throws -> Session? {
        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else { return nil }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        var firstTimestamp: Date?
        var gitBranch: String?
        var version: String?
        var usage = TokenUsage()
        var modelsUsed: [String: TokenUsage] = [:]
        var entries: [SessionEntry] = []

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

            let type = json["type"] as? String ?? ""
            let timestampStr = json["timestamp"] as? String
            let timestamp = timestampStr.flatMap { dateFormatter.date(from: $0) }

            if firstTimestamp == nil { firstTimestamp = timestamp }
            if gitBranch == nil { gitBranch = json["gitBranch"] as? String }
            if version == nil { version = json["version"] as? String }

            if type == "assistant", let message = json["message"] as? [String: Any] {
                let model = message["model"] as? String
                if let usageDict = message["usage"] as? [String: Any] {
                    let entryUsage = TokenUsage(
                        inputTokens: int64(usageDict["input_tokens"]),
                        outputTokens: int64(usageDict["output_tokens"]),
                        cacheCreationTokens: int64(usageDict["cache_creation_input_tokens"]),
                        cacheReadTokens: int64(usageDict["cache_read_input_tokens"])
                    )
                    usage.add(entryUsage)

                    if let model = model {
                        var modelUsage = modelsUsed[model] ?? TokenUsage()
                        modelUsage.add(entryUsage)
                        modelsUsed[model] = modelUsage
                    }

                    entries.append(SessionEntry(
                        timestamp: timestamp ?? Date(),
                        type: .assistant,
                        model: model,
                        usage: entryUsage,
                        toolName: nil,
                        content: nil
                    ))
                }

                // Extract tool_use from content
                if let contentArray = message["content"] as? [[String: Any]] {
                    for item in contentArray {
                        if item["type"] as? String == "tool_use" {
                            entries.append(SessionEntry(
                                timestamp: timestamp ?? Date(),
                                type: .toolUse,
                                model: model,
                                usage: nil,
                                toolName: item["name"] as? String,
                                content: nil
                            ))
                        }
                    }
                }
            }
        }

        guard firstTimestamp != nil else { return nil }

        return Session(
            id: sessionId,
            projectDirName: projectDirName,
            projectPath: projectPath,
            timestamp: firstTimestamp!,
            gitBranch: gitBranch,
            version: version,
            usage: usage,
            modelsUsed: modelsUsed,
            entries: entries
        )
    }

    private func int64(_ value: Any?) -> Int64 {
        if let i = value as? Int64 { return i }
        if let i = value as? Int { return Int64(i) }
        if let d = value as? Double { return Int64(d) }
        return 0
    }

    static func decodeProjectName(_ dirName: String) -> String {
        // Convert -Users-devsh-Documents-cnb-code-app-backend to app-backend
        let parts = dirName.split(separator: "-")
        // Find the meaningful project name after common path prefixes
        if let lastSlashIdx = dirName.lastIndex(of: "-") {
            // Try to extract just the last meaningful segment
            let components = dirName.components(separatedBy: "-").filter { !$0.isEmpty }
            // Skip common path components
            let skipPrefixes = ["Users", "Documents", "var", "folders", "private", "tmp", "T"]
            var meaningful: [String] = []
            var foundNonPrefix = false
            for comp in components {
                if !foundNonPrefix && skipPrefixes.contains(comp) { continue }
                if !foundNonPrefix && comp.count <= 3 { continue } // skip short path segments like "kv"
                foundNonPrefix = true
                meaningful.append(comp)
            }
            if meaningful.count > 1 {
                // Return last 1-2 segments as project name
                return meaningful.suffix(2).joined(separator: "/")
            }
            return meaningful.first ?? dirName
        }
        return dirName
    }

    enum ParserError: LocalizedError {
        case directoryNotFound(String)

        var errorDescription: String? {
            switch self {
            case .directoryNotFound(let path):
                return "Directory not found: \(path)"
            }
        }
    }
}
