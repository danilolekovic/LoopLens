import AVKit
import SwiftUI

struct VideoPlaybackView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.videoGravity = .resizeAspect
        context.coordinator.play(url: url, in: view)
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        guard context.coordinator.url != url else { return }
        context.coordinator.play(url: url, in: view)
    }

    static func dismantleNSView(_ view: AVPlayerView, coordinator: Coordinator) {
        coordinator.stop()
        view.player = nil
    }

    final class Coordinator {
        private(set) var url: URL?
        private var playbackObserver: NSObjectProtocol?

        func play(url: URL, in view: AVPlayerView) {
            stop()
            self.url = url

            let player = AVPlayer(url: url)
            view.player = player
            playbackObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
            player.play()
        }

        func stop() {
            if let playbackObserver {
                NotificationCenter.default.removeObserver(playbackObserver)
            }
            playbackObserver = nil
            url = nil
        }
    }
}
