import SwiftUI

struct SettingsView: View {
    @ObservedObject var captureStore: ScreenCaptureStore

    var body: some View {
        Form {
            Toggle("Collapse to a recording floaty", isOn: $captureStore.usesRecordingFloaty)
            Text("Hide the main window while recording and show a compact timer with a Stop button.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Hide LoopLens controls from recordings", isOn: $captureStore.excludesLoopLensFromCapture)
            Text("Exclude the editor and recording floaty from ScreenCaptureKit output.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460)
    }
}
