import SwiftUI

@main
struct ScreenOnApp: App {
    @StateObject private var model = ScreenOnModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onChange(of: scenePhase) { phase in
                    model.sceneChanged(phase)
                }
        }
    }
}
