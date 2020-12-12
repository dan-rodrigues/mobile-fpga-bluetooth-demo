// ContentView.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import SwiftUI

struct ContentView: View {

    private let viewModel: ContentViewModel

    init(viewModel: ContentViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text(viewModel.title)
                .padding()
            HStack {
                ForEach(viewModel.ledViewModels) { led in
                    LEDView(color: led.color, filled: led.lit)
                        .onTapGesture {
                            viewModel.ledToggleHandler(led.id)
                        }
                }
            }
            .frame(height: 96, alignment: .center)
            Button("Scan", action: viewModel.scanHandler)
                .disabled(!viewModel.scanEnabled)
            Button("Set all", action: viewModel.setAllHandler)
                .disabled(!viewModel.connectedActionsEnabled)
            Button("Clear all", action: viewModel.clearAllHandler)
                .disabled(!viewModel.connectedActionsEnabled)
        }
    }
}

private struct LEDView: View {

    private let filled: Bool
    private let color: UIColor

    init(color: UIColor, filled: Bool) {
        self.color = color
        self.filled = filled
    }

    var body: some View {
        Color(filled ? color : UIColor.systemBackground)
            .border(Color(UIColor.systemGray), width: 2)
    }
}
