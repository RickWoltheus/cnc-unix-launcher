import SwiftUI

struct LaunchStopButton: View {
    @ObservedObject var model: LauncherModel
    @State private var confirm = false

    var body: some View {
        Button(model.stoppingLaunch ? "Stopping…" : "Stop & retry") { confirm = true }
            .disabled(model.stoppingLaunch || (model.busy && !model.gameRunning))
            .accessibilityIdentifier("stop-launch")
            .confirmationDialog("Stop this game and its Steam session?", isPresented: $confirm) {
                Button("Stop & retry", role: .destructive) { model.stopLaunch() }
            } message: {
                Text("Unsaved progress may be lost. This stops the selected game and its launch processes. Installed files and saves are kept.")
            }
    }
}
