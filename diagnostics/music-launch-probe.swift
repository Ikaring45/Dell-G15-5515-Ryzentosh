import AppKit
import CoreGraphics
import Foundation

@main
struct MusicLaunchProbe {
    @MainActor static func main() async {
        let bundleID = "com.apple.Music"
        guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty else {
            print("MUSIC_ALREADY_RUNNING")
            return
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            print("MUSIC_NOT_FOUND")
            exit(1)
        }
        let start = ProcessInfo.processInfo.systemUptime
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        do {
            let app = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
            print(String(format: "MUSIC_LAUNCH_CALLBACK_SECONDS=%.3f", ProcessInfo.processInfo.systemUptime - start))
            let pid = Int(app.processIdentifier)
            while ProcessInfo.processInfo.systemUptime - start < 25 {
                let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
                if windows.contains(where: {
                    guard $0[kCGWindowOwnerPID as String] as? Int == pid,
                          $0[kCGWindowLayer as String] as? Int == 0,
                          let bounds = $0[kCGWindowBounds as String] as? [String: Double] else { return false }
                    return (bounds["Width"] ?? 0) >= 320 && (bounds["Height"] ?? 0) >= 240
                }) {
                    print(String(format: "MUSIC_FIRST_WINDOW_SECONDS=%.3f", ProcessInfo.processInfo.systemUptime - start))
                    return
                }
                try await Task.sleep(nanoseconds: 50_000_000)
            }
            print("MUSIC_FIRST_WINDOW_NOT_OBSERVED")
        } catch {
            print("MUSIC_LAUNCH_ERROR: \(error.localizedDescription)")
            exit(1)
        }
    }
}
