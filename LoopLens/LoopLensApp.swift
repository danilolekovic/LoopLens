//
//  LoopLensApp.swift
//  LoopLens
//
//  Created by Danilo Lekovic on 2026-10-13.
//

import SwiftUI

@main
struct LoopLensApp: App {
    @StateObject private var captureStore = ScreenCaptureStore()

    var body: some Scene {
        Window("LoopLens", id: "main") {
            ContentView(captureStore: captureStore)
        }

        MenuBarExtra {
            RecorderMenu(captureStore: captureStore)
        } label: {
            Label(
                "LoopLens",
                systemImage: captureStore.isRecording ? "record.circle.fill" : "record.circle"
            )
        }

        Settings {
            SettingsView(captureStore: captureStore)
        }
    }
}
