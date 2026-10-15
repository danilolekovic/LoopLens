import SwiftUI

struct SettingsView: View {
    @ObservedObject var captureStore: ScreenCaptureStore

    var body: some View {
        Form {
            Section("Recording") {
                Toggle("Collapse to a recording floaty", isOn: $captureStore.usesRecordingFloaty)
                Text("Hide the main window while recording and show a compact timer with a Stop button.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Hide LoopLens controls from recordings", isOn: $captureStore.excludesLoopLensFromCapture)
                Text("Exclude the editor and recording floaty from ScreenCaptureKit output.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("GIF output") {
                LabeledContent("Save to") {
                    Text(captureStore.outputFolderURL.path(percentEncoded: false))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }

                Text("The first recording asks once for folder access. Later recordings save automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Choose Folder…") {
                        captureStore.chooseOutputFolder()
                    }
                    Spacer()
                    Button("Restore Default") {
                        captureStore.restoreDefaultOutputFolder()
                    }
                    .disabled(captureStore.usesDefaultOutputFolder)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460)
    }
}
