import SwiftUI
import AppKit

@main
struct FLAC2MP3App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    NotificationService.requestPermission()
                }
                .onReceive(NotificationCenter.default.publisher(for: .openURLs)) { notification in
                    if let urls = notification.object as? [URL] {
                        NotificationCenter.default.post(name: .init("LoadURLs"), object: urls)
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Abrir archivo o carpeta...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = true
                    if panel.runModal() == .OK {
                        NotificationCenter.default.post(name: .openURLs, object: panel.urls)
                    }
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let openURLs = Notification.Name("OpenURLs")
    static let openFolder = Notification.Name("OpenFolder")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }
        NotificationCenter.default.post(name: .openURLs, object: urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

