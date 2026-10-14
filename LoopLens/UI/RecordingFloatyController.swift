import AppKit
import SwiftUI

@MainActor
final class RecordingFloatyController {
    private let panel: NSPanel

    init(stopAction: @escaping @MainActor () -> Void) {
        let content = RecordingFloatyView(startedAt: .now, stopAction: stopAction)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = CGRect(x: 0, y: 0, width: 190, height: 52)

        panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
    }

    func show(on screen: NSScreen?) {
        let visibleFrame = (screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let origin = CGPoint(
            x: visibleFrame.maxX - panel.frame.width - 18,
            y: visibleFrame.maxY - panel.frame.height - 18
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    func close() {
        panel.orderOut(nil)
    }
}

private struct RecordingFloatyView: View {
    let startedAt: Date
    let stopAction: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.red)
                .frame(width: 9, height: 9)

            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                Text(elapsedTime(at: context.date))
                    .monospacedDigit()
                    .fontWeight(.medium)
            }

            Spacer(minLength: 4)

            Button {
                stopAction()
            } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .help("Stop recording")
        }
        .padding(.horizontal, 12)
        .frame(width: 190, height: 52)
        .background(.ultraThickMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.14)))
    }

    private func elapsedTime(at date: Date) -> String {
        let elapsed = max(0, Int(date.timeIntervalSince(startedAt)))
        return String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }
}
