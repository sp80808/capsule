import SwiftUI

@main
struct CapsuleApp: App {
    var body: some Scene {
        WindowGroup {
            AudioMixerView()
                .frame(minWidth: 600, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
