import Foundation

enum Shell {
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
    /// Callers must invoke this off the main actor - every scanner function in
    /// this app runs inside `Task.detached` for exactly that reason.
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

        if sem.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return Result(status: -1, stdout: "", stderr: "timeout")
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        return Result(
            status: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
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
