// FPGABluetoothDemo.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import SwiftUI

@main
struct FPGABluetoothDemo: App {

    @StateObject var appContext = AppContext()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: self.appContext.viewModel)
        }
        .onChange(of: self.scenePhase) { phase in
            if phase == .active {
                self.appContext.appBecameActive()
            }
        }
    }
}
