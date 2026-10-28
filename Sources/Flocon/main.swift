import AppKit

if let index = CommandLine.arguments.firstIndex(of: "--dump-desktop"), index + 1 < CommandLine.arguments.count {
    try? DesktopIcons.dump().write(toFile: CommandLine.arguments[index + 1], atomically: true, encoding: .utf8)
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
