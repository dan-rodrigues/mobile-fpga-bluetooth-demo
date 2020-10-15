// ContentViewModel.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import Foundation
import UIKit

/// A model of the application state at any given time, suitable for SwiftUI views.

struct ContentViewModel {

    typealias Handler = () -> Void
    typealias ToggleHandler = (_ ledIndex: Int) -> Void

    struct LEDViewModel: Identifiable {

        let id: Int
        let color: UIColor
        let lit: Bool
    }

    static let placeholder = ContentViewModel(
        title: "...",
        scanEnabled: false,
        connectedActionsEnabled: false,
        ledViewModels: [],
        scanHandler: {},
        setAllHandler: {},
        clearAllHandler: {},
        ledToggleHandler: { _ in }
    )

    let title: String
    let scanEnabled: Bool
    let connectedActionsEnabled: Bool

    let ledViewModels: [LEDViewModel]

    let scanHandler: Handler
    let setAllHandler: Handler
    let clearAllHandler: Handler
    let ledToggleHandler: ToggleHandler
}
