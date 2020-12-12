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
            ContentView(viewModel: appContext.viewModel)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                appContext.appBecameActive()
            }
        }
    }
}
