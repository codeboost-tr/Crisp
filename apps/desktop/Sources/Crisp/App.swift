import SwiftUI

@main
struct CrispApp: App {
    @State private var model = CleanModel()
    @State private var updater = Updater()

    var body: some Scene {
        Window(Channel.current.displayName, id: "main") {
            ContentView(model: model, updater: updater)
                .frame(minWidth: 540, minHeight: 600)
                .task { updater.checkOnLaunch() }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 600, height: 760)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    Task { await updater.check(userInitiated: true) }
                }
                .disabled(!Channel.current.updatesEnabled || updater.isBusy)
            }
        }
    }
}
