import AppKit
import SwiftUI

struct AnimatedGIFView: NSViewRepresentable {
    let url: URL

    final class Coordinator {
        var loadedURL: URL?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        return imageView
    }

    func updateNSView(_ imageView: NSImageView, context: Context) {
        if context.coordinator.loadedURL != url {
            imageView.image = NSImage(contentsOf: url)
            context.coordinator.loadedURL = url
        }
        imageView.animates = true
    }
}
