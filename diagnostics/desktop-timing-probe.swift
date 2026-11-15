import AppKit
import Carbon
import Darwin
import Foundation

func counter(_ name: String) -> UInt64? {
    var value: UInt64 = 0
    var size = MemoryLayout<UInt64>.size
    guard sysctlbyname(name, &value, &size, nil, 0) == 0,
          size == 8 || size == 4 else { return nil }
    return value
}

func inputSource() -> String {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
        return "unavailable"
    }
    return Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
}

let seconds = min(max(Int(CommandLine.arguments.dropFirst().first ?? "45") ?? 45, 1), 120)
let clock = DispatchTime.now().uptimeNanoseconds
let format = ISO8601DateFormatter()
format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
var previousApp: String?
var previousInput: String?
var previousFlips = counter("debug.nvrmfb_flip_n")
var previousSample = clock
print("Records active application, input source and display flip counts. No keystrokes or window contents.")
for tick in 0..<(seconds * 10) {
    let stamp = format.string(from: Date())
    let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unavailable"
    if app != previousApp {
        print("\(stamp) active_app=\(app)")
        previousApp = app
    }
    let input = inputSource()
    if input != previousInput {
        print("\(stamp) input_source=\(input)")
        previousInput = input
    }
    if tick > 0 && tick % 10 == 0 {
        let now = DispatchTime.now().uptimeNanoseconds
        let flips = counter("debug.nvrmfb_flip_n")
        if let count = flips, let old = previousFlips, count >= old {
            let rate = Double(count - old) * 1_000_000_000 / Double(now - previousSample)
            print("\(stamp) " + String(format: "display_flips_per_s=%.1f", rate))
        }
        previousFlips = flips
        previousSample = now
    }
    fflush(stdout)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
}
