import AppKit
import SwiftUI

struct RecorderMenu: View {
    @ObservedObject var captureStore: ScreenCaptureStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open LoopLens") {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        Divider()

        if captureStore.isRecording {
            Button("Stop Recording") {
                Task { await captureStore.stopRecording() }
            }
        } else {
            Button("Start Recording") {
                Task { await captureStore.startRecording() }
            }
            .disabled(captureStore.selectedDisplay == nil || captureStore.isBusy)

            Button("Select Region…") {
                Task { await captureStore.selectRegion() }
            }
            .disabled(captureStore.selectedDisplay == nil || captureStore.isBusy)
        }

        Divider()

        SettingsLink {
            Text("Settings…")
        }

        Button("Quit LoopLens") {
            NSApplication.shared.terminate(nil)
        }
    }
}
