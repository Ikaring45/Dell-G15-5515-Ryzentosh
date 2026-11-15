import AppKit
import Foundation

let defaults = ["Calendar", "Clock", "Calculator", "Notes", "Music", "System Settings"]
let apps = CommandLine.arguments.count > 1 ? Array(CommandLine.arguments.dropFirst()) : defaults
let root = URL(fileURLWithPath: "/System/Applications", isDirectory: true)

func milliseconds(since start: UInt64) -> Double {
    Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
}

for name in apps {
    let url = root.appendingPathComponent("\(name).app", isDirectory: true)
    guard FileManager.default.fileExists(atPath: url.path) else {
        print("\(name): bundle unavailable")
        continue
    }
    for attempt in 1...3 {
        autoreleasepool {
            let lookupStarted = DispatchTime.now().uptimeNanoseconds
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            let lookup = milliseconds(since: lookupStarted)
            var rect = CGRect(x: 0, y: 0, width: 64, height: 64)
            let renderStarted = DispatchTime.now().uptimeNanoseconds
            let output = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil)
            let render = milliseconds(since: renderStarted)
            let size = output.map { "\($0.width)x\($0.height)" } ?? "unavailable"
            print(String(format: "%@ run=%d lookup_ms=%.2f image_ms=%.2f output=%@",
                         name, attempt, lookup, render, size))
        }
    }
}
