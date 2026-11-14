import Foundation
import Darwin

/// Disk and memory stats read straight from the kernel (statvfs / Mach host
/// APIs) instead of shelling out to `df`/`vm_stat` and parsing text - this
/// also sidesteps the old hardcoded-page-size bug entirely, since the real
/// page size comes straight from `host_page_size`.
enum DiskRamService {
    static func diskStatus() -> DiskStatus {
        let path = FileManager.default.fileExists(atPath: "/System/Volumes/Data") ? "/System/Volumes/Data" : "/"
        var stat = statvfs()
        guard statvfs(path, &stat) == 0 else { return DiskStatus() }

        let total = UInt64(stat.f_blocks) * UInt64(stat.f_frsize)
        let free = UInt64(stat.f_bavail) * UInt64(stat.f_frsize)
        let used = total > free ? total - free : 0
        let percentUsed = total > 0 ? (Double(used) / Double(total)) * 100 : 0
        let percentFree = total > 0 ? (Double(free) / Double(total)) * 100 : 0

        return DiskStatus(
            total: formatBytes(Int64(total)), totalBytes: total,
            used: formatBytes(Int64(used)), usedBytes: used,
            free: formatBytes(Int64(free)), freeBytes: free,
            percentUsed: (percentUsed * 10).rounded() / 10,
            percentFree: (percentFree * 10).rounded() / 10
        )
    }

    static func ramInfo() -> RamInfo {
        let memSize = ProcessInfo.processInfo.physicalMemory

        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        var stats = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &stats) { statsPtr -> kern_return_t in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &size)
            }
        }
        guard result == KERN_SUCCESS else { return RamInfo() }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let p = Int64(pageSize)

        let free = (Int64(stats.free_count) + Int64(stats.speculative_count)) * p
        let active = Int64(stats.active_count) * p
        let inactive = Int64(stats.inactive_count) * p
        let wired = Int64(stats.wire_count) * p
        let used = active + wired
        let usedPercent = memSize > 0 ? (Double(used) / Double(memSize)) * 100 : 0

        return RamInfo(
            total: formatBytes(Int64(memSize)), totalBytes: memSize,
            used: formatBytes(used),
            free: formatBytes(free),
            active: formatBytes(active),
            inactive: formatBytes(inactive),
            wired: formatBytes(wired),
            usedPercent: (usedPercent * 10).rounded() / 10
        )
    }
}
