// Prints the on-screen window ID for the first regular window owned by the
// given PID. Uses the public CGWindowList API, which — unlike AppleScript /
// System Events — does not require Accessibility permission, so it can be
// invoked headlessly from screenshot automation.
//
// Usage: swift Scripts/find-window-id.swift <pid>
// Exit codes: 0 on success (id printed to stdout), 1 if no window found.

import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2,
      let pid = pid_t(CommandLine.arguments[1])
else {
    FileHandle.standardError.write(Data("Usage: find-window-id.swift <pid>\n".utf8))
    exit(2)
}

let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let entries = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}

for entry in entries {
    guard
        let owner = entry[kCGWindowOwnerPID as String] as? pid_t, owner == pid,
        let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
        let id = entry[kCGWindowNumber as String] as? CGWindowID
    else { continue }
    print(id)
    exit(0)
}

exit(1)
