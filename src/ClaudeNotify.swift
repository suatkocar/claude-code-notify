import Foundation
import UserNotifications
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var title = "Claude Code"
    var message = "Notification"
    var sound = "Glass"
    var terminalApp: String? = nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        // If we know which terminal Claude is running in, check if it's focused
        if let terminal = terminalApp, !terminal.isEmpty {
            if let frontmostApp = NSWorkspace.shared.frontmostApplication {
                let appName = frontmostApp.localizedName ?? ""
                let bundleId = frontmostApp.bundleIdentifier ?? ""

                // Map TERM_PROGRAM values to app names/bundle IDs
                let isTerminalFocused: Bool
                switch terminal.lowercased() {
                case "warpterminal", "warp":
                    isTerminalFocused = appName == "Warp" || bundleId.contains("dev.warp")
                case "apple_terminal":
                    isTerminalFocused = appName == "Terminal" || bundleId.contains("com.apple.Terminal")
                case "iterm.app", "iterm":
                    isTerminalFocused = appName == "iTerm2" || appName == "iTerm" || bundleId.contains("com.googlecode.iterm2")
                case "vscode", "code":
                    isTerminalFocused = appName.contains("Visual Studio Code") || appName.contains("Code") || bundleId.contains("com.microsoft.VSCode")
                case "alacritty":
                    isTerminalFocused = appName == "Alacritty" || bundleId.contains("alacritty")
                case "kitty":
                    isTerminalFocused = appName == "kitty" || bundleId.contains("net.kovidgoyal.kitty")
                case "hyper":
                    isTerminalFocused = appName == "Hyper" || bundleId.contains("co.zeit.hyper")
                default:
                    // Unknown terminal, try direct name match
                    isTerminalFocused = appName.lowercased().contains(terminal.lowercased())
                }

                if isTerminalFocused {
                    // Terminal is focused, skip notification
                    NSApplication.shared.terminate(nil)
                    return
                }
            }
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                self.sendNotification()
            } else {
                NSLog("Notification permission denied")
                NSApplication.shared.terminate(nil)
            }
        }
    }

    func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(sound).aiff"))

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("Error: \(error.localizedDescription)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

// Parse arguments
var titleArg = "Claude Code"
var messageArg = "Notification"
var soundArg = "Glass"
var terminalArg: String? = nil

let args = CommandLine.arguments
var i = 1
while i < args.count {
    switch args[i] {
    case "-t", "--title":
        if i + 1 < args.count { titleArg = args[i + 1]; i += 1 }
    case "-m", "--message":
        if i + 1 < args.count { messageArg = args[i + 1]; i += 1 }
    case "-s", "--sound":
        if i + 1 < args.count { soundArg = args[i + 1]; i += 1 }
    case "--terminal":
        if i + 1 < args.count { terminalArg = args[i + 1]; i += 1 }
    default: break
    }
    i += 1
}

let app = NSApplication.shared
let delegate = AppDelegate()
delegate.title = titleArg
delegate.message = messageArg
delegate.sound = soundArg
delegate.terminalApp = terminalArg
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
