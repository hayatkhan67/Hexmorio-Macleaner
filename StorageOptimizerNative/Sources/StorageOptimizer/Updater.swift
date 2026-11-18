import Foundation
import AppKit
import Security

struct AvailableUpdate: Equatable {
    let version: String
    let downloadURL: URL
    let releaseURL: URL
}

/// Checks GitHub Releases for a newer build and installs it in place.
/// Release assets are produced by release.sh.
enum Updater {
    static let zipAssetName = "Hexmorio-Macleaner.zip"
    private static let lastCheckKey = "lastUpdateCheck"

    static var repo: String? { Bundle.main.object(forInfoDictionaryKey: "HexmorioUpdateRepo") as? String }
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var installCommand: String {
        "curl -fsSL https://github.com/\(repo ?? "")/releases/latest/download/install.sh | bash"
    }

    static var isCheckDue: Bool {
        let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        return Date().timeIntervalSince(last) > 24 * 60 * 60
    }

    static func checkForUpdate() async throws -> AvailableUpdate? {
        guard let repo, let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)
        // 404 = no releases published yet.
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        struct Release: Decodable {
            struct Asset: Decodable { let name: String; let browser_download_url: URL }
            let tag_name: String
            let html_url: URL
            let assets: [Asset]
        }
        let release = try JSONDecoder().decode(Release.self, from: data)
        let version = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
        guard isNewer(version, than: currentVersion),
              let asset = release.assets.first(where: { $0.name == zipAssetName }) else { return nil }
        return AvailableUpdate(version: version, downloadURL: asset.browser_download_url, releaseURL: release.html_url)
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        a.compare(b, options: .numeric) == .orderedDescending
    }

    /// Downloads and verifies the update, then hands off to a helper script that
    /// swaps the bundle once this process quits and relaunches the new version.
    static func install(_ update: AvailableUpdate) async throws {
        let fm = FileManager.default
        let currentApp = Bundle.main.bundlePath
        let parentDir = (currentApp as NSString).deletingLastPathComponent
        guard fm.isWritableFile(atPath: parentDir) else {
            throw UpdateError("Can't write to \(parentDir). Update from Terminal instead:\n\(installCommand)")
        }

        let (downloaded, _) = try await URLSession.shared.download(from: update.downloadURL)
        let workDir = fm.temporaryDirectory.appendingPathComponent("hexmorio-update-\(UUID().uuidString)")
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
        let zipPath = workDir.appendingPathComponent(zipAssetName).path
        try fm.moveItem(atPath: downloaded.path, toPath: zipPath)

        let unzip = Shell.run("/usr/bin/ditto", ["-x", "-k", zipPath, workDir.path], timeout: 60)
        guard unzip.ok else { throw UpdateError("Couldn't unpack update: \(unzip.stderr)") }
        guard let appName = try fm.contentsOfDirectory(atPath: workDir.path).first(where: { $0.hasSuffix(".app") }) else {
            throw UpdateError("Update archive didn't contain an app")
        }
        let newApp = workDir.appendingPathComponent(appName).path
        try verifySameDeveloper(newApp)

        let script = """
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.5; done
        rm -rf "$2.new"
        if /usr/bin/ditto "$1" "$2.new"; then
            rm -rf "$2" && mv "$2.new" "$2"
            /usr/bin/xattr -dr com.apple.quarantine "$2" 2>/dev/null
        fi
        /usr/bin/open "$2"
        rm -rf "$3"
        """
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/bash")
        helper.arguments = ["-c", script, "updater", newApp, currentApp, workDir.path]
        try helper.run()

        await MainActor.run { NSApp.terminate(nil) }
    }

    /// Refuses an update unless it's signed by the same developer as the running app.
    private static func verifySameDeveloper(_ appPath: String) throws {
        var selfCode: SecCode?
        var selfStatic: SecStaticCode?
        var requirement: SecRequirement?
        var newCode: SecStaticCode?
        guard SecCodeCopySelf([], &selfCode) == errSecSuccess, let selfCode,
              SecCodeCopyStaticCode(selfCode, [], &selfStatic) == errSecSuccess, let selfStatic,
              SecCodeCopyDesignatedRequirement(selfStatic, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(URL(fileURLWithPath: appPath) as CFURL, [], &newCode) == errSecSuccess, let newCode
        else { throw UpdateError("Couldn't read code signatures to verify the update") }

        let status = SecStaticCodeCheckValidity(newCode, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), requirement)
        guard status == errSecSuccess else {
            throw UpdateError("Update isn't signed by the same developer - not installing it. Update from Terminal instead:\n\(installCommand)")
        }
    }
}

struct UpdateError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
