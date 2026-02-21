import SwiftUI

@main
struct PoliApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window is managed by AppDelegate via NSWindow.
        // An empty Settings scene is required to satisfy the App protocol.
        Settings { EmptyView() }
    }
}
