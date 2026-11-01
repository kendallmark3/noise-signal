import SwiftUI

@main
struct NoiseSignalApp: App {
    /// Created once for the app's lifetime; never recreated during view updates.
    @StateObject private var viewModel = NoiseSignalViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
