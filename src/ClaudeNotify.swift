import Foundation
import UserNotifications
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var title = "Claude Code"
    var message = "Notification"
    var sound = "Glass"

    func applicationDidFinishLaunching(_ notification: Notification) {
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
    default: break
    }
    i += 1
}

let app = NSApplication.shared
let delegate = AppDelegate()
delegate.title = titleArg
delegate.message = messageArg
delegate.sound = soundArg
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
