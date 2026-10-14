import SwiftUI

struct ContentView: View {
    @StateObject private var captureStore = ScreenCaptureStore()

    var body: some View {
        NavigationSplitView {
            sourceList
        } detail: {
            preview
        }
        .frame(minWidth: 780, minHeight: 520)
        .task {
            await captureStore.loadDisplays()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await captureStore.loadDisplays() }
                } label: {
                    Label("Refresh displays", systemImage: "arrow.clockwise")
                }
                .disabled(captureStore.isBusy)

                Button {
                    Task { await captureStore.capturePreview() }
                } label: {
                    Label("Capture preview", systemImage: "camera")
                }
                .disabled(captureStore.selectedDisplay == nil || captureStore.isBusy)
            }
        }
    }

    private var sourceList: some View {
        List(captureStore.displays, selection: $captureStore.selectedDisplayID) { display in
            VStack(alignment: .leading, spacing: 4) {
                Text(display.name)
                    .fontWeight(.medium)
                Text(display.resolutionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 3)
            .tag(display.id)
        }
        .navigationTitle("Displays")
        .navigationSplitViewColumnWidth(min: 210, ideal: 240)
        .overlay {
            if captureStore.displays.isEmpty {
                ContentUnavailableView {
                    Label("No displays", systemImage: "display")
                } description: {
                    Text("Refresh after allowing screen recording access.")
                }
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch captureStore.state {
        case .idle, .loading:
            ProgressView("Finding displays…")
                .controlSize(.large)

        case .permissionRequired:
            ContentUnavailableView {
                Label("Screen Recording Access", systemImage: "rectangle.dashed.badge.record")
            } description: {
                Text("LoopLens needs permission to see and record your displays.")
            } actions: {
                Button("Allow Screen Recording") {
                    Task { await captureStore.requestPermission() }
                }
                .buttonStyle(.borderedProminent)
            }

        case let .failed(message):
            ContentUnavailableView {
                Label("Unable to Load Displays", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await captureStore.loadDisplays() }
                }
            }

        case .ready, .capturingPreview:
            previewContent
        }
    }

    private var previewContent: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            if let image = captureStore.previewImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.16), radius: 18, y: 7)
                    .padding(32)
            } else {
                ContentUnavailableView {
                    Label("Ready to Capture", systemImage: "record.circle")
                } description: {
                    if let display = captureStore.selectedDisplay {
                        Text("Capture a preview of \(display.name) to verify access.")
                    } else {
                        Text("Select a display from the sidebar.")
                    }
                } actions: {
                    Button("Capture Preview") {
                        Task { await captureStore.capturePreview() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(captureStore.selectedDisplay == nil)
                }
            }

            if captureStore.state == .capturingPreview {
                ProgressView()
                    .controlSize(.large)
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .navigationTitle(captureStore.selectedDisplay?.name ?? "Capture Preview")
    }
}

#Preview {
    ContentView()
}
