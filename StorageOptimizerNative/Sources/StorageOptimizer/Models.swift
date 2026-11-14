import Foundation

func formatBytes(_ bytes: Int64) -> String {
    if bytes < 1024 { return "\(bytes) B" }
    let kb = Double(bytes) / 1024
    if kb < 1024 { return String(format: "%.1f KB", kb) }
    let mb = kb / 1024
    if mb < 1024 { return String(format: "%.1f MB", mb) }
    let gb = mb / 1024
    return String(format: "%.2f GB", gb)
}

struct DiskStatus {
    var total = "--"
    var totalBytes: UInt64 = 0
    var used = "--"
    var usedBytes: UInt64 = 0
    var free = "--"
    var freeBytes: UInt64 = 0
    var percentUsed: Double = 0
    var percentFree: Double = 0
}

struct RamInfo {
    var total = "--"
    var totalBytes: UInt64 = 0
    var used = "--"
    var free = "--"
    var active = "--"
    var inactive = "--"
    var wired = "--"
    var usedPercent: Double = 0
}

enum Safety: String { case safe = "SAFE", rebuildable = "REBUILDABLE", review = "REVIEW" }

enum CleanActionKind {
    case deleteContents, recreateDir, npmClean, pubClean, simErase, emptyTrash
}

struct CleanTargetDef {
    let id: String
    let category: String // "developer" | "system"
    let name: String
    let path: String
    let description: String
    let safety: Safety
    let action: CleanActionKind
}

struct CleanTarget: Identifiable {
    let id: String
    let category: String
    let name: String
    let path: String
    let description: String
    let safety: Safety
    let action: CleanActionKind
    var sizeBytes: Int64 = 0
    var exists: Bool = false
    var sizeFormatted: String { formatBytes(sizeBytes) }
}

struct LibraryItem: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let category: String
    var sizeBytes: Int64
    let description: String
    let canClean: Bool
    var sizeFormatted: String { formatBytes(sizeBytes) }
}

struct AppInfo: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let sizeBytes: Int64
    let isUserApp: Bool
    var sizeFormatted: String { formatBytes(sizeBytes) }
}

struct BrewPackage: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let sizeBytes: Int64
    var sizeFormatted: String { formatBytes(sizeBytes) }
}
struct NpmPackage: Identifiable { var id: String { name }; let name: String; let version: String }
struct PipPackage: Identifiable { var id: String { name }; let name: String; let version: String }

struct StartupItem: Identifiable {
    var id: String { path }
    let fileName: String
    let path: String
    let type: String
    let label: String
    let program: String
    let isDisabled: Bool
    let canToggle: Bool
}

struct ProjectArtifact: Identifiable {
    var id: String { path }
    let project: String
    let type: String
    let typeLabel: String
    let path: String
    let sizeBytes: Int64
    var sizeFormatted: String { formatBytes(sizeBytes) }
}

struct DuplicateFile: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let sizeBytes: Int64
    let modified: Date
}

struct DuplicateGroup: Identifiable {
    let id: String // hash
    let fileSizeBytes: Int64
    var files: [DuplicateFile]
    var fileSizeFormatted: String { formatBytes(fileSizeBytes) }
}

struct InstallerFile: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let sizeBytes: Int64
    var sizeFormatted: String { formatBytes(sizeBytes) }
}

struct GitRepo: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let sizeBytes: Int64
    var sizeFormatted: String { formatBytes(sizeBytes) }
}

struct LeftoverItem: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let sizeBytes: Int64
    var sizeFormatted: String { formatBytes(sizeBytes) }
}

struct TreeItem: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let isDir: Bool
    let sizeBytes: Int64
    var sizeFormatted: String { formatBytes(sizeBytes) }
}

struct LargeFile: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let sizeBytes: Int64
    var sizeFormatted: String { formatBytes(sizeBytes) }
}
