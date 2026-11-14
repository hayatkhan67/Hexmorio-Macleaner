import Foundation
import SwiftUI

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let isError: Bool
}

struct PendingAction: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let perform: () -> Void
}

@MainActor
final class AppState: ObservableObject {
    // Status / Disk / RAM
    @Published var statusText = "Ready"
    @Published var disk = DiskStatus()
    @Published var ram = RamInfo()
    @Published var toast: ToastMessage?
    @Published var pendingAction: PendingAction?
    @Published var isReleasingMemory = false

    // Optimizer tab
    @Published var targets: [CleanTarget] = []
    @Published var selectedIds: Set<String> = []
    @Published var currentCategory = "all"
    @Published var autoCleanEnabled = false
    @Published var isScanningTargets = false

    // Library tab
    @Published var library: LibraryScanResult?
    @Published var libraryFilter = "all"
    @Published var isScanningLibrary = false

    // Apps tab
    @Published var apps: [AppInfo] = []
    @Published var isScanningApps = false

    // Packages tab
    @Published var packages: PackagesScanResult?
    @Published var isScanningPackages = false

    // Startup tab
    @Published var startupItems: [StartupItem] = []
    @Published var isScanningStartup = false

    // Disk map tab
    @Published var diskMapPath = ""
    @Published var diskMapParent: String?
    @Published var diskMapItems: [TreeItem] = []
    @Published var diskMapShowHidden = true
    @Published var isScanningDiskMap = false

    // Project builds tab
    @Published var projects: [ProjectArtifact] = []
    @Published var isScanningProjects = false

    // Leftovers tab
    @Published var leftovers: [LeftoverItem] = []
    @Published var isScanningLeftovers = false

    // Git repos tab
    @Published var gitRepos: [GitRepo] = []
    @Published var isScanningGit = false

    // Duplicates tab
    @Published var duplicates: [DuplicateGroup] = []
    @Published var selectedDupePaths: Set<String> = []
    @Published var isScanningDuplicates = false

    // Installers tab
    @Published var installers: [InstallerFile] = []
    @Published var isScanningInstallers = false

    // Large files tab
    @Published var largeFiles: [LargeFile] = []
    @Published var minMB = 50
    @Published var isScanningLargeFiles = false

    func showToast(_ message: String, isError: Bool = false) {
        toast = ToastMessage(message: message, isError: isError)
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if self.toast?.message == message { self.toast = nil }
        }
    }

    func confirm(title: String, message: String, perform: @escaping () -> Void) {
        pendingAction = PendingAction(title: title, message: message, perform: perform)
    }

    // MARK: - Disk / RAM

    func refreshDiskAndRam() async {
        let d = await Task.detached { DiskRamService.diskStatus() }.value
        let r = await Task.detached { DiskRamService.ramInfo() }.value
        disk = d
        ram = r
    }

    // MARK: - Optimizer

    func scanTargets() async {
        isScanningTargets = true
        let result = await Task.detached { CleanTargetsService.scan() }.value
        targets = result.items
        isScanningTargets = false
    }

    var filteredTargets: [CleanTarget] {
        currentCategory == "all" ? targets : targets.filter { $0.category == currentCategory }
    }

    var safeTotalBytes: Int64 { targets.filter { $0.safety == .safe }.reduce(0) { $0 + $1.sizeBytes } }
    var rebuildableBytes: Int64 { targets.filter { $0.safety == .rebuildable }.reduce(0) { $0 + $1.sizeBytes } }

    func toggleTargetSelection(_ id: String) {
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
    }

    func cleanTargets(ids: [String]) async {
        statusText = "Cleaning \(ids.count) item(s)..."
        for id in ids {
            let needsAdmin = CleanTargetsService.needsAdmin(id)
            _ = await Task.detached { CleanTargetsService.execute(id, asAdmin: needsAdmin) }.value
        }
        selectedIds.subtract(ids)
        showToast("Cleaned \(ids.count) item(s) successfully!")
        statusText = "Ready"
        await rescanAll()
    }

    func rescanAll() async {
        statusText = "Deep Scanning..."
        async let t: Void = scanTargets()
        async let l: Void = scanLibrary()
        async let p: Void = scanProjects()
        async let d: Void = refreshDiskAndRam()
        _ = await (t, l, p, d)
        autoCleanEnabled = await Task.detached { SystemActions.isAutoCleanEnabled() }.value
        statusText = "Ready"
    }

    // MARK: - Library

    func scanLibrary() async {
        isScanningLibrary = true
        let result = await Task.detached { LibraryScanner.scan() }.value
        library = result
        isScanningLibrary = false
    }

    var filteredLibraryItems: [LibraryItem] {
        guard let library else { return [] }
        var items: [LibraryItem] = []
        if libraryFilter == "all" || libraryFilter == "user_library" { items += library.userLibrary }
        if libraryFilter == "all" || libraryFilter == "app_support" { items += library.appSupport }
        if libraryFilter == "all" || libraryFilter == "user_caches" { items += library.userCaches }
        if libraryFilter == "all" || libraryFilter == "hidden_folders" { items += library.hiddenFolders }
        if libraryFilter == "all" || libraryFilter == "system_library" { items += library.systemLibrary }
        return items.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    func cleanLibraryFolder(_ path: String, _ name: String) async {
        statusText = "Purging \(name)..."
        let (ok, msg) = await Task.detached { SafeDelete.cleanFolderContents(path) }.value
        if ok {
            showToast("Purged \(name) contents successfully!")
            await scanLibrary()
            await refreshDiskAndRam()
        } else {
            showToast(msg, isError: true)
        }
        statusText = "Ready"
    }

    // MARK: - Apps

    func scanApps() async {
        isScanningApps = true
        let result = await Task.detached { AppsScanner.scan() }.value
        apps = result.apps
        isScanningApps = false
    }

    // MARK: - Packages

    func scanPackages() async {
        isScanningPackages = true
        let result = await Task.detached { PackagesScanner.scan() }.value
        packages = result
        isScanningPackages = false
    }

    func runBrewCleanup() async {
        statusText = "Cleaning brew packages..."
        _ = await Task.detached { Shell.run("brew", ["cleanup", "--prune=all"], timeout: 30) }.value
        showToast("Brew cleanup complete!")
        await refreshDiskAndRam()
        await scanPackages()
        statusText = "Ready"
    }

    // MARK: - Startup

    func scanStartup() async {
        isScanningStartup = true
        let result = await Task.detached { StartupScanner.scan() }.value
        startupItems = result.items
        isScanningStartup = false
    }

    func toggleStartup(_ path: String) async {
        let (_, msg) = await Task.detached { StartupScanner.toggle(path) }.value
        showToast(msg)
        await scanStartup()
    }

    // MARK: - Disk map

    func loadDiskMap(_ path: String) async {
        isScanningDiskMap = true
        let showHidden = diskMapShowHidden
        let result = await Task.detached { FolderTreeScanner.scan(path: path, showHidden: showHidden) }.value
        diskMapPath = result.currentPath
        diskMapParent = result.parentPath
        diskMapItems = result.items
        isScanningDiskMap = false
    }

    func openInDiskMap(_ path: String) -> String { path }

    // MARK: - Project builds

    func scanProjects() async {
        isScanningProjects = true
        let result = await Task.detached { ProjectBuildsScanner.scan() }.value
        projects = result
        isScanningProjects = false
    }

    func cleanProjectPath(_ path: String, _ label: String) async {
        statusText = "Cleaning \(label)..."
        let (ok, msg) = await Task.detached { SafeDelete.deletePath(path) }.value
        if ok {
            showToast("Cleaned \(label)")
            await refreshDiskAndRam()
            await scanProjects()
        } else {
            showToast("Error: \(msg)", isError: true)
        }
        statusText = "Ready"
    }

    func cleanAllProjectBuilds() async {
        let builds = projects.filter { $0.type == "build" || $0.type == ".dart_tool" || $0.type == "node_modules" }
        guard !builds.isEmpty else { showToast("No build directories to clean."); return }
        statusText = "Cleaning all project builds..."
        var count = 0
        for b in builds {
            let (ok, _) = await Task.detached { SafeDelete.deletePath(b.path) }.value
            if ok { count += 1 }
        }
        showToast("Cleaned \(count) project build directories!")
        await refreshDiskAndRam()
        await scanProjects()
        statusText = "Ready"
    }

    // MARK: - Leftovers

    func scanLeftovers() async {
        isScanningLeftovers = true
        let result = await Task.detached { LeftoversScanner.scan() }.value
        leftovers = result
        isScanningLeftovers = false
    }

    func cleanLeftoverPath(_ path: String, _ name: String) async {
        let (ok, msg) = await Task.detached { SafeDelete.deletePath(path) }.value
        if ok {
            showToast("Deleted leftover for \(name)")
            await refreshDiskAndRam()
            await scanLeftovers()
        } else {
            showToast(msg, isError: true)
        }
    }

    // MARK: - Git repos

    func scanGitRepos() async {
        isScanningGit = true
        let result = await Task.detached { GitReposScanner.scan() }.value
        gitRepos = result
        isScanningGit = false
    }

    func optimizeSingleGit(_ path: String, _ name: String) async {
        statusText = "Compressing \(name)..."
        _ = await Task.detached { GitReposScanner.optimize(path) }.value
        showToast("Compressed git repo: \(name)")
        await scanGitRepos()
        statusText = "Ready"
    }

    func optimizeAllGitRepos() async {
        guard !gitRepos.isEmpty else { return }
        statusText = "Compressing all git repos..."
        for repo in gitRepos {
            _ = await Task.detached { GitReposScanner.optimize(repo.path) }.value
        }
        showToast("Optimized \(gitRepos.count) repositories!")
        await scanGitRepos()
        statusText = "Ready"
    }

    // MARK: - Duplicates

    func scanDuplicates() async {
        isScanningDuplicates = true
        let result = await Task.detached { DuplicatesScanner.scan() }.value
        duplicates = result.groups
        selectedDupePaths.removeAll()
        for g in duplicates { for f in g.files.dropFirst() { selectedDupePaths.insert(f.path) } }
        isScanningDuplicates = false
    }

    func cleanSelectedDuplicates() async {
        let paths = Array(selectedDupePaths)
        guard !paths.isEmpty else { return }
        var count = 0
        for p in paths {
            let (ok, _) = await Task.detached { SafeDelete.deletePath(p) }.value
            if ok { count += 1 }
        }
        showToast("Deleted \(count) duplicate files!")
        await refreshDiskAndRam()
        await scanDuplicates()
    }

    // MARK: - Installers

    func scanInstallers() async {
        isScanningInstallers = true
        let result = await Task.detached { InstallersScanner.scan() }.value
        installers = result.installers
        isScanningInstallers = false
    }

    // MARK: - Large files

    func loadLargeFiles() async {
        isScanningLargeFiles = true
        let mb = minMB
        let result = await Task.detached { LargeFilesScanner.scan(minMB: mb) }.value
        largeFiles = result
        isScanningLargeFiles = false
    }

    func deleteLargeFile(_ path: String) async {
        let (ok, msg) = await Task.detached { SafeDelete.moveToTrash(path) }.value
        if ok {
            showToast("File moved to Trash")
            await loadLargeFiles()
            if !installers.isEmpty { await scanInstallers() }
            await refreshDiskAndRam()
        } else {
            showToast("Failed to delete file: \(msg)", isError: true)
        }
    }

    // MARK: - Shared actions

    func revealInFinder(_ path: String) {
        SystemActions.revealInFinder(path)
    }

    func toggleAutoClean() async {
        let newState = !autoCleanEnabled
        let enabled = await Task.detached { SystemActions.setAutoClean(newState) }.value
        autoCleanEnabled = enabled
        showToast(newState ? "Automated weekly cleanup enabled!" : "Automated cleanup disabled.")
    }

    func systemFlush() async {
        statusText = "Flushing caches..."
        _ = await Task.detached { SystemActions.flushSystemCaches() }.value
        showToast("Flushed QuickLook thumbnail & DNS caches!")
        await refreshDiskAndRam()
        statusText = "Ready"
    }

    func releaseMemory() async {
        guard !isReleasingMemory else { return }
        isReleasingMemory = true
        statusText = "Releasing memory..."
        let (_, message) = await Task.detached { SystemActions.releaseMemory() }.value
        showToast(message)
        await refreshDiskAndRam()
        statusText = "Ready"
        isReleasingMemory = false
    }
}
