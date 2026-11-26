import Foundation

enum ProjectLocations {
    /// Non-project system, media, and global-cache trees under `~` or `/Volumes`
    /// that should never be walked when searching for user source projects.
    /// Global caches (`~/.gradle`, `~/.pub-cache`, `~/.npm`, `~/Library`, etc.)
    /// are already handled separately by `CleanTargetsService` and `LibraryScanner`.
    static let skippedDirectoryNames: Set<String> = [
        "Library", ".Trash", ".Trashes", "Pictures", "Music", "Movies",
        "Public", "Applications", "System", ".Spotlight-V100", ".fseventsd",
        ".TemporaryItems", ".DocumentRevisions-V100", ".MobileBackups",
        // Global tool/package caches in $HOME (handled in Optimizer / Library tabs)
        ".cache", ".npm", ".pnpm-store", ".yarn", ".pub-cache", ".gradle",
        ".m2", ".ivy2", ".sbt", ".cargo", ".rustup", ".nvm", ".pyenv",
        ".rbenv", ".gem", ".bundle", ".cocoapods", ".local", ".dartServer",
        ".shorebird", ".expo", ".android", ".vscode", ".cursor", ".windsurf",
        ".claude", ".gemini", ".codex", ".antigravity", ".antigravity-ide",
        ".chrome-play-console", ".ollama", ".docker", ".kube", ".minikube"
    ]

    /// Files or directories whose presence in a folder confirms that the folder
    /// is a software project root (used to distinguish project `build`/`dist`/`target`
    /// folders from random non-project folders).
    static let projectMarkerFiles: Set<String> = [
        "pubspec.yaml", "package.json", "Package.swift", "Cargo.toml",
        "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts",
        "pom.xml", "Podfile", "Cartfile", "pyproject.toml", "requirements.txt",
        "setup.py", "Pipfile", "CMakeLists.txt", "Makefile", "go.mod",
        "composer.json", "Gemfile", "mix.exs", "deno.json", "bun.lockb",
        "tsconfig.json", "next.config.js", "next.config.mjs", "next.config.ts",
        "vite.config.js", "vite.config.ts", "angular.json", "flutter.yaml",
        ".git", "android", "ios"
    ]

    /// Returns top-level search roots covering the entire user home directory
    /// and any mounted user/external volumes (excluding macOS system volumes
    /// and Time Machine backups), deduplicated by on-disk `(device, inode)`.
    static func searchRoots(fm: FileManager = .default, home: String = NSHomeDirectory()) -> [String] {
        var candidates: [String] = [home]

        if let volumes = try? fm.contentsOfDirectory(atPath: "/Volumes") {
            let systemVolumePrefixes = [
                "Macintosh HD", "Recovery", "Preboot", "Update", "VM",
                "xarts", "iSCPreboot", "Hardware", "com.apple."
            ]
            for vol in volumes where !vol.hasPrefix(".") {
                if systemVolumePrefixes.contains(where: { vol == $0 || vol.hasPrefix($0) }) {
                    continue
                }
                let volPath = "/Volumes/\(vol)"
                let resolved = (volPath as NSString).resolvingSymlinksInPath
                if resolved == "/" || resolved == "/System/Volumes/Data" { continue }
                // Skip Time Machine backup volumes
                if fm.fileExists(atPath: "\(volPath)/Backups.backupdb") ||
                   fm.fileExists(atPath: "\(volPath)/.backup_manifest.plist") {
                    continue
                }
                candidates.append(volPath)
            }
        }

        var seen = Set<String>()
        var result: [String] = []
        for path in candidates {
            let resolved = (path as NSString).resolvingSymlinksInPath
            guard let attrs = try? fm.attributesOfItem(atPath: resolved),
                  attrs[.type] as? FileAttributeType == .typeDirectory,
                  let device = attrs[.systemNumber],
                  let inode = attrs[.systemFileNumber]
            else { continue }
            guard seen.insert("\(device):\(inode)").inserted else { continue }
            result.append(path)
        }
        return result
    }

    /// Legacy compatibility helper used by callers expecting common roots;
    /// now delegates to `searchRoots` so no directory on the Mac is missed.
    static func roots(fm: FileManager = .default, home: String = NSHomeDirectory()) -> [String] {
        searchRoots(fm: fm, home: home)
    }

    /// Checks whether a directory looks like a software project (or sub-project).
    static func isLikelyProjectDirectory(_ dirPath: String, fm: FileManager = .default) -> Bool {
        guard let entries = try? fm.contentsOfDirectory(atPath: dirPath) else { return false }
        for entry in entries {
            if projectMarkerFiles.contains(entry) { return true }
            if entry.hasSuffix(".xcodeproj") || entry.hasSuffix(".xcworkspace") || entry.hasSuffix(".sln") || entry.hasSuffix(".csproj") {
                return true
            }
        }
        return false
    }

    /// Formats a clean, readable project name relative to home or volume root.
    static func displayLabel(forProjectDir projectDir: String, home: String = NSHomeDirectory()) -> String {
        if projectDir.hasPrefix(home + "/") {
            var rel = String(projectDir.dropFirst(home.count + 1))
            // Strip leading common container name (e.g. "projects/my_app" -> "my_app",
            // "projects/shop_app/admin" -> "shop_app/admin") when there are still path components left.
            let commonContainers: Set<String> = [
                "projects", "Projects", "Developer", "Code", "code", "dev",
                "workspace", "Workspace", "repos", "Repos", "src", "Sites"
            ]
            let parts = rel.split(separator: "/")
            if parts.count >= 2, commonContainers.contains(String(parts[0])) {
                rel = parts.dropFirst().joined(separator: "/")
            }
            return rel
        }
        return (projectDir as NSString).lastPathComponent
    }
}

enum ProjectBuildsScanner {
    /// Directories whose name alone unambiguously identifies a project build or dependency cache.
    private static let unambiguousArtifacts: [String: (type: String, label: String)] = [
        "node_modules": ("node_modules", "Node Modules"),
        ".dart_tool": (".dart_tool", "Dart Tool Cache"),
        "Pods": ("Pods", "CocoaPods Pods"),
        ".next": (".next", "Next.js Build Cache"),
        ".nuxt": (".nuxt", "Nuxt Build Cache"),
        ".turbo": (".turbo", "Turborepo Cache"),
        ".parcel-cache": (".parcel-cache", "Parcel Build Cache"),
        ".angular": (".angular", "Angular Cache"),
        ".svelte-kit": (".svelte-kit", "SvelteKit Build"),
        ".gradle": (".gradle", "Project Gradle Cache"),
        "DerivedData": ("DerivedData", "Xcode DerivedData"),
        ".pytest_cache": (".pytest_cache", "Pytest Cache"),
        "__pycache__": ("__pycache__", "Python Bytecode Cache"),
        "CMakeFiles": ("CMakeFiles", "CMake Build Files"),
        ".venv": (".venv", "Python Virtual Env"),
        "venv": ("venv", "Python Virtual Env"),
    ]

    /// Directories that are build outputs when located inside a recognized project directory.
    private static let contextualArtifacts: [String: (type: String, label: String)] = [
        "build": ("build", "Project Build Output"),
        ".build": (".build", "SwiftPM / Native Build"),
        "dist": ("dist", "Distribution Build"),
        "target": ("target", "Rust / Maven Target"),
    ]

    /// Allowed dot-directories that we should inspect during project traversal
    /// (all other dot-directories are skipped so we don't crawl hidden app state).
    private static let inspectableDotDirs: Set<String> = [
        ".dart_tool", ".next", ".nuxt", ".turbo", ".parcel-cache",
        ".angular", ".svelte-kit", ".gradle", ".pytest_cache",
        ".venv", ".build"
    ]

    private static let maxTraversalDepth = 7

    private struct CandidateArtifact {
        let projectDir: String
        let type: String
        let typeLabel: String
        let path: String
    }

    static func scan() -> [ProjectArtifact] {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let hasFDA = Permissions.hasFullDiskAccess
        var candidates: [CandidateArtifact] = []
        var seenArtifactPaths = Set<String>()

        for root in ProjectLocations.searchRoots(fm: fm, home: home) {
            let rootDepth = root.split(separator: "/").count
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey],
                options: [.skipsPackageDescendants]
            ) else { continue }

            while true {
                var finished = false
                autoreleasepool {
                    guard let nextObj = enumerator.nextObject() else {
                        finished = true
                        return
                    }
                    guard let url = nextObj as? URL else { return }
                    let name = url.lastPathComponent
                    let fullPath = url.path

                    guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey]),
                          values.isDirectory == true else { return }

                    // Never follow directory symlinks or traverse inside .app / .framework bundles
                    if values.isSymbolicLink == true || values.isPackage == true ||
                       name.hasSuffix(".app") || name.hasSuffix(".framework") ||
                       name.hasSuffix(".xcarchive") || name.hasSuffix(".photoslibrary") {
                        enumerator.skipDescendants()
                        return
                    }

                    // Skip system/protected directories and global caches. A name like `.gradle`
                    // is a global cache only at the top of a search root (`~/.gradle`); inside a
                    // project (`android/.gradle`) it is a per-project build cache we want to report.
                    let parentPath = (fullPath as NSString).deletingLastPathComponent
                    let isNestedArtifact = unambiguousArtifacts[name] != nil && parentPath != root
                    if ProjectLocations.skippedDirectoryNames.contains(name) && !isNestedArtifact {
                        enumerator.skipDescendants()
                        return
                    }
                    if !hasFDA && Permissions.isProtected(fullPath) {
                        enumerator.skipDescendants()
                        return
                    }
                    if name == ".git" {
                        enumerator.skipDescendants()
                        return
                    }

                    // Ignore other hidden dot-folders unless they are a known build artifact
                    if name.hasPrefix(".") && !inspectableDotDirs.contains(name) {
                        enumerator.skipDescendants()
                        return
                    }

                    // Depth guard so we never wander arbitrarily deep into non-project file trees
                    let depth = fullPath.split(separator: "/").count - rootDepth
                    if depth > maxTraversalDepth {
                        enumerator.skipDescendants()
                        return
                    }

                    // 1. Unambiguous build/cache artifact directory
                    if let match = unambiguousArtifacts[name] {
                        let parentDir = (fullPath as NSString).deletingLastPathComponent
                        // Skip python venvs or node_modules that aren't inside a project
                        if (name == "venv" || name == ".venv" || name == ".gradle") && !ProjectLocations.isLikelyProjectDirectory(parentDir, fm: fm) {
                            enumerator.skipDescendants()
                            return
                        }
                        if seenArtifactPaths.insert(fullPath).inserted {
                            candidates.append(CandidateArtifact(
                                projectDir: parentDir,
                                type: match.type,
                                typeLabel: match.label,
                                path: fullPath
                            ))
                        }
                        enumerator.skipDescendants()
                        return
                    }

                    // 2. Contextual build directories (`build`, `.build`, `dist`, `target`)
                    // These names are also common for real source/asset folders (`scripts/build`,
                    // Go's `build/` packaging dir, electron-builder's `build/` resources), and
                    // "Clean All Builds" deletes permanently. So only accept them when the
                    // *direct* parent has a marker for a tool that writes that exact folder,
                    // and never when git tracks files inside it.
                    if let match = contextualArtifacts[name] {
                        let parentDir = (fullPath as NSString).deletingLastPathComponent
                        if isGeneratedBuildDirectory(name: name, parentDir: parentDir, fm: fm) {
                            let label = refinedBuildLabel(name: name, parentDir: parentDir, fm: fm, defaultLabel: match.label)
                            if seenArtifactPaths.insert(fullPath).inserted {
                                candidates.append(CandidateArtifact(
                                    projectDir: parentDir,
                                    type: match.type,
                                    typeLabel: label,
                                    path: fullPath
                                ))
                            }
                            enumerator.skipDescendants()
                            return
                        }
                    }
                }
                if finished { break }
            }
        }

        guard !candidates.isEmpty else { return [] }

        // Measure all discovered artifact directories concurrently using native fastDirectorySize
        // (no 2-second subprocess timeout, so 7GB+ builds are always measured accurately).
        let lock = NSLock()
        var results: [ProjectArtifact] = []

        DispatchQueue.concurrentPerform(iterations: candidates.count) { idx in
            autoreleasepool {
                let candidate = candidates[idx]
                let bytes = FolderSizeCache.fastDirectorySize(atPath: candidate.path)
                // Only surface artifacts > 1 MB
                guard bytes > 1024 * 1024 else { return }
                let projectLabel = ProjectLocations.displayLabel(forProjectDir: candidate.projectDir, home: home)
                let artifact = ProjectArtifact(
                    project: projectLabel,
                    type: candidate.type,
                    typeLabel: candidate.typeLabel,
                    path: candidate.path,
                    sizeBytes: bytes
                )
                lock.lock()
                results.append(artifact)
                lock.unlock()
            }
        }

        results.sort { $0.sizeBytes > $1.sizeBytes }
        return results
    }

    /// Project files that prove the parent's tool generates a folder of the given name.
    private static let generatorMarkers: [String: [String]] = [
        "build": ["pubspec.yaml", "build.gradle", "build.gradle.kts", "CMakeLists.txt",
                  "package.json", "pyproject.toml", "setup.py"],
        ".build": ["Package.swift"],
        "dist": ["package.json", "pyproject.toml", "setup.py"],
        "target": ["Cargo.toml", "pom.xml", "build.sbt"],
    ]

    private static func isGeneratedBuildDirectory(name: String, parentDir: String, fm: FileManager) -> Bool {
        guard let markers = generatorMarkers[name] else { return false }
        var hasMarker = markers.contains { fm.fileExists(atPath: "\(parentDir)/\($0)") }
        // Legacy Xcode projects write `build/` next to the .xcodeproj.
        if !hasMarker, name == "build",
           let entries = try? fm.contentsOfDirectory(atPath: parentDir) {
            hasMarker = entries.contains { $0.hasSuffix(".xcodeproj") }
        }
        guard hasMarker else { return false }
        return !containsGitTrackedFiles(name: name, parentDir: parentDir, fm: fm)
    }

    /// True when `parentDir/name` holds files committed to git, i.e. it is source,
    /// not output. Only runs git when the folder is inside a repository and a real
    /// git binary exists (the /usr/bin/git stub would pop up an install dialog).
    private static func containsGitTrackedFiles(name: String, parentDir: String, fm: FileManager) -> Bool {
        var dir = parentDir
        var inRepo = false
        while dir != "/" && !dir.isEmpty {
            if fm.fileExists(atPath: "\(dir)/.git") { inRepo = true; break }
            dir = (dir as NSString).deletingLastPathComponent
        }
        guard inRepo, let git = gitExecutable else { return false }
        let res = Shell.run(git, ["-C", parentDir, "ls-files", "--", name], timeout: 5)
        // If git fails we can't prove the folder is generated; err on the side of keeping it.
        guard res.ok else { return true }
        return !res.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static let gitExecutable: String? = {
        let fm = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/git",
            "/usr/local/bin/git",
            "/Library/Developer/CommandLineTools/usr/bin/git",
            "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
        ]
        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }()

    private static func refinedBuildLabel(name: String, parentDir: String, fm: FileManager, defaultLabel: String) -> String {
        if name == "build" {
            if fm.fileExists(atPath: "\(parentDir)/pubspec.yaml") { return "Flutter Build" }
            if fm.fileExists(atPath: "\(parentDir)/build.gradle") ||
               fm.fileExists(atPath: "\(parentDir)/build.gradle.kts") { return "Android / Gradle Build" }
            if fm.fileExists(atPath: "\(parentDir)/CMakeLists.txt") { return "CMake Build" }
            if fm.fileExists(atPath: "\(parentDir)/package.json") { return "Web / JS Build" }
        } else if name == "target" {
            if fm.fileExists(atPath: "\(parentDir)/Cargo.toml") { return "Rust Cargo Target" }
            if fm.fileExists(atPath: "\(parentDir)/pom.xml") { return "Maven Target" }
        }
        return defaultLabel
    }
}

enum GitReposScanner {
    private static let maxTraversalDepth = 6

    static func scan() -> [GitRepo] {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let hasFDA = Permissions.hasFullDiskAccess
        var gitDirs: [(repoDir: String, gitPath: String)] = []
        var seen = Set<String>()

        for root in ProjectLocations.searchRoots(fm: fm, home: home) {
            let rootDepth = root.split(separator: "/").count
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey],
                options: [.skipsPackageDescendants]
            ) else { continue }

            while true {
                var finished = false
                autoreleasepool {
                    guard let nextObj = enumerator.nextObject() else {
                        finished = true
                        return
                    }
                    guard let url = nextObj as? URL else { return }
                    let name = url.lastPathComponent
                    let fullPath = url.path

                    guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey]),
                          values.isDirectory == true else { return }

                    if values.isSymbolicLink == true || values.isPackage == true ||
                       name.hasSuffix(".app") || name.hasSuffix(".framework") {
                        enumerator.skipDescendants()
                        return
                    }

                    if name == ".git" {
                        let repoDir = (fullPath as NSString).deletingLastPathComponent
                        if seen.insert(fullPath).inserted {
                            gitDirs.append((repoDir, fullPath))
                        }
                        enumerator.skipDescendants()
                        return
                    }

                    if name.hasPrefix(".") ||
                       ProjectLocations.skippedDirectoryNames.contains(name) ||
                       ["node_modules", "Pods", "build", "dist", "target", "venv", "DerivedData"].contains(name) ||
                       (!hasFDA && Permissions.isProtected(fullPath)) {
                        enumerator.skipDescendants()
                        return
                    }

                    let depth = fullPath.split(separator: "/").count - rootDepth
                    if depth > maxTraversalDepth {
                        enumerator.skipDescendants()
                        return
                    }
                }
                if finished { break }
            }
        }

        let lock = NSLock()
        var results: [GitRepo] = []

        DispatchQueue.concurrentPerform(iterations: gitDirs.count) { idx in
            autoreleasepool {
                let item = gitDirs[idx]
                let bytes = FolderSizeCache.fastDirectorySize(atPath: item.gitPath)
                guard bytes > 2 * 1024 * 1024 else { return }
                let label = ProjectLocations.displayLabel(forProjectDir: item.repoDir, home: home)
                let repo = GitRepo(name: label, path: item.repoDir, sizeBytes: bytes)
                lock.lock()
                results.append(repo)
                lock.unlock()
            }
        }

        results.sort { $0.sizeBytes > $1.sizeBytes }
        return results
    }

    @discardableResult
    static func optimize(_ path: String) -> (success: Bool, message: String) {
        let result = Shell.run("git", ["-C", path, "gc", "--prune=now"], timeout: 30)
        return result.ok ? (true, "Optimized git repository") : (false, result.stderr)
    }
}

enum LeftoversScanner {
    static func scan() -> [LeftoverItem] {
        let fm = FileManager.default
        let home = NSHomeDirectory()

        var installedNames = Set<String>()
        var installedBundleIds = Set<String>()

        for dir in ["/Applications", "/System/Applications", "\(home)/Applications"] {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let appName = (item as NSString).deletingPathExtension.lowercased()
                let normalized = appName.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
                installedNames.insert(normalized)
                let plistPath = "\(dir)/\(item)/Contents/Info.plist"
                if let data = fm.contents(atPath: plistPath),
                   let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                   let bundleId = (plist["CFBundleIdentifier"] as? String)?.lowercased() {
                    installedBundleIds.insert(bundleId)
                }
            }
        }

        let scanLocations: [(label: String, path: String)] = [
            ("App Support", "\(home)/Library/Application Support"),
            ("Caches", "\(home)/Library/Caches"),
            ("Containers", "\(home)/Library/Containers"),
            ("Saved State", "\(home)/Library/Saved Application State"),
        ]

        let systemSkipPrefixes = [
            "com.apple.", "apple.", "cloudkit", "familycircle", "passkit",
            "geoservices", "gamekit", "homekit", "knowledge", "bluetooth",
            "crashreporter", "animoji", "avatarkit", "caches", "google",
            "org.swift.", "pip", "typescript", "node-gyp", "homebrew", "cocoapods"
        ]

        var candidates: [(name: String, path: String)] = []
        for loc in scanLocations {
            if !Permissions.hasFullDiskAccess && Permissions.isProtected(loc.path) { continue }
            guard let items = try? fm.contentsOfDirectory(atPath: loc.path) else { continue }
            for name in items where !name.hasPrefix(".") {
                let lower = name.lowercased()
                if systemSkipPrefixes.contains(where: { lower == $0 || lower.hasPrefix($0) }) { continue }

                let full = (loc.path as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { continue }

                let cleanName = lower
                    .replacingOccurrences(of: ".savedstate", with: "")
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "-", with: "")

                let matchesBundle = installedBundleIds.contains { lower == $0 || lower.hasPrefix($0 + ".") || $0.contains(cleanName) }
                let matchesName = installedNames.contains { !$0.isEmpty && (cleanName.contains($0) || $0.contains(cleanName)) }
                guard !matchesBundle && !matchesName else { continue }

                candidates.append(("\(name) (\(loc.label))", full))
            }
        }

        let lock = NSLock()
        var results: [LeftoverItem] = []

        DispatchQueue.concurrentPerform(iterations: candidates.count) { idx in
            autoreleasepool {
                let c = candidates[idx]
                let bytes = FolderSizeCache.fastDirectorySize(atPath: c.path)
                guard bytes > 3 * 1024 * 1024 else { return }
                lock.lock()
                results.append(LeftoverItem(name: c.name, path: c.path, sizeBytes: bytes))
                lock.unlock()
            }
        }

        results.sort { $0.sizeBytes > $1.sizeBytes }
        return results
    }
}
