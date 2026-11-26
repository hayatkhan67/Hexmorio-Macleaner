import Foundation

enum Shell {
    /// Lock-guarded stdout/stderr storage shared with the pipe reader threads.
    private final class PipeBuffers: @unchecked Sendable {
        private let lock = NSLock()
        private var out = Data()
        private var err = Data()
        func set(out data: Data) { lock.lock(); out = data; lock.unlock() }
        func set(err data: Data) { lock.lock(); err = data; lock.unlock() }
        func snapshot() -> (Data, Data) { lock.lock(); defer { lock.unlock() }; return (out, err) }
    }

    struct Result {
        let status: Int32
        let stdout: String
        let stderr: String
        var ok: Bool { status == 0 }
    }

    /// A GUI app launched from Finder/LaunchServices gets launchd's bare
    /// session PATH (roughly /usr/bin:/bin:/usr/sbin:/sbin), not the PATH a
    /// login shell builds from .zprofile/.zshrc. Tools installed via nvm,
    /// Homebrew, or ~/.local/bin (npm, node, pip, brew) are invisible to
    /// `/usr/bin/env` as a result, even though they work fine in Terminal.
    /// Widen PATH with the common install locations before resolving names.
    private static func enrichedEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        var extraPaths = [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
        ]
        let nvmVersionsDir = "\(home)/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmVersionsDir) {
            for v in versions.sorted(by: >) {
                extraPaths.append("\(nvmVersionsDir)/\(v)/bin")
            }
        }
        let existing = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = (extraPaths + [existing]).joined(separator: ":")
        return env
    }

    /// Runs an external tool synchronously (blocking the calling thread/task).
    /// Drains stdout and stderr concurrently while the process runs so a child
    /// writing >64KB to either pipe never deadlocks waiting for the buffer to drain.
    @discardableResult
    static func run(_ executable: String, _ args: [String] = [], timeout: TimeInterval = 5) -> Result {
        let process = Process()
        process.environment = enrichedEnvironment()
        if executable.hasPrefix("/") {
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args
        } else {
            // Resolve non-absolute names via PATH, same as a shell would.
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable] + args
        }
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let sem = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in sem.signal() }

        do {
            try process.run()
        } catch {
            return Result(status: -1, stdout: "", stderr: "\(error)")
        }

        // The reader threads may still be running if we stop waiting early, so the
        // buffers live behind a lock instead of being shared mutable locals.
        let buffers = PipeBuffers()
        let drainGroup = DispatchGroup()

        drainGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            buffers.set(out: data)
            drainGroup.leave()
        }

        drainGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            buffers.set(err: data)
            drainGroup.leave()
        }

        if sem.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            _ = drainGroup.wait(timeout: .now() + 0.5)
            let (out, _) = buffers.snapshot()
            return Result(
                status: -1,
                stdout: String(data: out, encoding: .utf8) ?? "",
                stderr: "timeout"
            )
        }

        _ = drainGroup.wait(timeout: .now() + 2)
        let (out, err) = buffers.snapshot()
        return Result(
            status: process.terminationStatus,
            stdout: String(data: out, encoding: .utf8) ?? "",
            stderr: String(data: err, encoding: .utf8) ?? ""
        )
    }

    /// Runs a tool that needs administrator rights via a native macOS
    /// authorization prompt (AppleScript's "with administrator privileges"),
    /// instead of silently doing nothing like the old background daemon did
    /// when it lacked permission.
    @discardableResult
    static func runAsAdmin(_ shellCommand: String) -> Result {
        let escaped = shellCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        return run("/usr/bin/osascript", ["-e", script], timeout: 60)
    }
}
