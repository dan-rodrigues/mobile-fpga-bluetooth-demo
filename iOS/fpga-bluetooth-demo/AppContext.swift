// AppContext.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import Foundation
import Combine
import UIKit

/// Provides the observable source of truth to generate SwiftUI views.
///
/// The observable `viewModel` property can be used to automatically generate
/// views when the application state changes, whether it is change initiated by
/// this app or by the peripheral.
///
/// Details of how the state is generated, including peripheral management, is an
/// implementation detail.

final class AppContext: ObservableObject {

    private let peripheralController: LEDPeripheralController

    @Published var viewModel: ContentViewModel = .placeholder
    private var cancellables = Set<AnyCancellable>()

    init(peripheralController: LEDPeripheralController = .init()) {
        self.peripheralController = peripheralController

        self.peripheralController.$state
            .map { state in
                ContentViewModel(
                    title: state.title,
                    scanEnabled: state == .readyToConnect,
                    connectedActionsEnabled: state.connected,
                    ledViewModels: state.ledViewModels,
                    scanHandler: { [weak peripheralController] in
                        peripheralController?.scan()
                    },
                    setAllHandler: { [weak peripheralController] in
                        peripheralController?.setLEDState(0xff)
                    },
                    clearAllHandler: { [weak peripheralController] in
                        peripheralController?.setLEDState(0x00)
                    },
                    ledToggleHandler: { [weak peripheralController] index in
                        peripheralController?.toggleLED(at: index)
                    }
                )
            }
            .eraseToAnyPublisher()
            .assign(to: \.viewModel, on: self)
            .store(in: &self.cancellables)
    }

    func appBecameActive() {
        self.peripheralController.refresh()
    }
}

private extension LEDPeripheralController.State {

    private static let colorPattern: [UIColor] = [
        .systemTeal, .systemGreen, .systemYellow, .systemRed
    ]

    var ledViewModels: [ContentViewModel.LEDViewModel] {
        switch self {
        case let .connected(connection):
            return connection.ledStates.reversed().enumerated().map { offset, element in
                switch element {
                case let .determined(lit):
                    return .init(id: offset, color: Self.colorPattern[offset % Self.colorPattern.count], lit: lit)
                case .indeterminate:
                    return .init(id: offset, color: .darkGray, lit: true)
                }
            }
        default:
            let defaultPlaceholderCount = 8
            return (0..<defaultPlaceholderCount).map { offset in
                .init(id: offset, color: .darkGray, lit: false)
            }
        }
    }

    var title: String {
        switch self {
        case .readyToConnect: return NSLocalizedString("Ready to scan", comment: "")
        case .off: return NSLocalizedString("Bluetooth is disabled", comment: "")
        case .unknown: return NSLocalizedString("Bluetooth in unknown state", comment: "")
        case .unauthorized: return NSLocalizedString("App not authorized to use Bluetooth", comment: "")
        case .connected: return NSLocalizedString("Connected", comment: "")
        case .connecting: return NSLocalizedString("Connecting...", comment: "")
        case .scanning: return NSLocalizedString("Scanning...", comment: "")
        }
    }

    var connected: Bool {
        if case .connected = self {
            return true
        } else {
            return false
        }
    }
}
