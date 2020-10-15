// LEDPeripheralController.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import Foundation
import Combine
import CoreBluetooth
import os

/// Provides an interface to an LED peripheral.
///
/// The interface consists of two parts:
/// * An observable `state` property
/// * Functions to establish a connection to a peripheral and update its value.
///   Resulting updates are automatically made available through `state`.
///
/// Details of how the peripheral is managed is an implementation detail.

final class LEDPeripheralController:
    NSObject,
    CBCentralManagerDelegate,
    CBPeripheralDelegate,
    ObservableObject
{
    enum State: Equatable {

        struct Connection: Equatable {

            let peripheral: CBPeripheral
            let writeCharacteristic: CBCharacteristic
            let readCharacteristic: CBCharacteristic
            var ledStates: [LEDState]
        }

        case readyToConnect

        case scanning
        case connecting(CBPeripheral)
        case connected(Connection)

        case unauthorized
        case off
        case unknown
    }

    enum LEDState: Equatable {

        case determined(lit: Bool)
        case indeterminate
    }

    private let manager: CBCentralManager
    private let ledCount: Int
    private let initialLEDState: UInt8

    @Published var state: State = .unknown

    private var currentLEDBits: UInt8 {
        guard case let .connected(connection) = self.state else { return 0 }

        return connection.ledStates.reduce(0) { bits, led in
            switch led {
            case let .determined(lit):
                return (bits << 1) | (lit ? 1 : 0)
            case .indeterminate:
                return bits << 1
            }
        }
    }

    init(ledCount: Int = 8, initialLEDState: UInt8 = 0xaa) {
        self.ledCount = ledCount
        self.initialLEDState = initialLEDState
        self.manager = CBCentralManager(delegate: nil, queue: nil, options: [:])

        super.init()

        self.manager.delegate = self
    }

    func scan() {
        guard self.state == .readyToConnect else { return }

        self.manager.scanForPeripherals(withServices: [Service.ledService.uuid], options: nil)
        self.state = .scanning
    }

    func setLEDState(_ state: UInt8) {
        guard case let .connected(connection) = self.state else { return }

        connection.peripheral.writeValue(
            Data([state]),
            for: connection.writeCharacteristic,
            type: .withResponse
        )
    }

    func refresh() {
        guard case let .connected(connection) = self.state else { return }

        // _IRQ_GATTS_READ_REQUEST is apparently not supported on ESP32
        // If it were, readValue() would be used here instead of the write->notify loop
        // http://docs.micropython.org/en/latest/library/ubluetooth.html#event-handling
        //
        // connection.peripheral.readValue(for: connection.readCharacteristic)

        connection.peripheral.writeValue(Data([self.currentLEDBits]), for: connection.writeCharacteristic, type: .withResponse)
    }

    func toggleLED(at index: Int) {
        precondition(index < self.ledCount)

        guard case let .connected(connection) = self.state else { return }
        guard connection.ledStates.count == self.ledCount else { return }
        guard case .determined = connection.ledStates[index] else { return }

        let updatedBits = self.currentLEDBits ^ (1 << index);

        // A toggled LED is in an indeterminate state until the peripheral replies
        var leds = connection.ledStates
        leds[index] = .indeterminate

        self.setLEDState(updatedBits)
    }

    private func connect(to peripheral: CBPeripheral) {
        self.state = .connecting(peripheral)
        self.manager.connect(peripheral, options: nil)
    }

    private func didSucceed(accordingTo error: Error?, task attemptedTask: String) -> Bool {
        if let error = error {
            os_log(.error, "Failed during task: %@, error: %@",
                   attemptedTask, error.localizedDescription)
            return false
        } else {
            return true
        }
    }

    // MARK: CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let newState = central.state

        switch (self.state, newState) {
        case (.connected, .poweredOn), (.connected, .unknown):
            break
        default:
            self.state = newState.connectionState
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        os_log("Discovered peripheral with data: %@", advertisementData)

        central.stopScan()
        self.connect(to: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        os_log(.error, "Failed to connect with error: %@", error?.localizedDescription ?? "(no error)")

        // Simplfy default to retrying the connection regardless of cause
        self.connect(to: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log("Connected to: %@", peripheral)

        peripheral.delegate = self
        peripheral.discoverServices([Service.ledService.uuid])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        os_log(.error, "Disconnected with error: %@", error?.localizedDescription ?? "(no error)")
        self.state = central.state.connectionState
    }

    // MARK: CBPeripheralManagerDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard self.didSucceed(accordingTo: error, task: "service discovery") else { return }
        guard let services = peripheral.services else {
            os_log(.error, "Expected peripheral to have at least one service")
            return
        }
        guard let service = services.first(where: { $0.uuid == Service.ledService.uuid }) else {
            os_log(.error, "Expected peripheral to have LED service")
            return
        }

        peripheral.discoverCharacteristics(Service.ledService.allCharacteristicUUIDs, for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let failureAction = {
            self.manager.cancelPeripheralConnection(peripheral)
        }

        guard self.didSucceed(accordingTo: error, task: "characteristic discovery") else {
            failureAction(); return
        }
        guard let readCharacteristic = service.characteristic(modelledBy: .ledRead) else {
            failureAction(); return
        }
        guard let writeCharacteristic = service.characteristic(modelledBy: .ledWrite) else {
            failureAction(); return
        }

        self.state = .connected(
            .init(
                peripheral: peripheral,
                writeCharacteristic: writeCharacteristic,
                readCharacteristic: readCharacteristic,
                ledStates: Array(repeating: .indeterminate, count: self.ledCount)
            )
        )

        peripheral.setNotifyValue(true, for: readCharacteristic)
        peripheral.writeValue(Data([self.initialLEDState]), for: writeCharacteristic, type: .withResponse)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            os_log(.error, "Failed to enable characteristic notiications: %@", error.localizedDescription)
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard self.didSucceed(accordingTo: error, task: "characteristic notifying") else { return }
        guard let ledBits = characteristic.value?.first else {
            os_log(.error, "Expected characterisic to have a value")
            return
        }
        guard case var .connected(connection) = self.state else { return }

        connection.ledStates = (0..<self.ledCount).map { shift in
            .determined(lit: ((ledBits >> shift) & 1) != 0)
        }

        self.state = .connected(connection)

        os_log("Characteristic value updated: %d", ledBits)
    }
}

private struct Service {

    static let ledService = Service(
        uuid: CBUUID(string: "AF3A6BE1-7F43-4BFD-8BDB-7F884F8E2D60"),
        characteristics: [.ledRead, .ledWrite]
    )

    let uuid: CBUUID
    let characteristics: [Characteristic]

    var allCharacteristicUUIDs: [CBUUID] {
        return self.characteristics.map { $0.uuid }
    }
}

private struct Characteristic {

    static let ledRead = Characteristic(
        name: "LED read",
        uuid: CBUUID(string: "8280CFA5-437A-4C0E-819D-BCD7A401BFA1"),
        expectedProperties: [.read, .notify]
    )

    static let ledWrite = Characteristic(
        name: "LED write",
        uuid: CBUUID(string: "4ECEF2E1-64C5-4E97-9955-EC389560A055"),
        expectedProperties: [.write]
    )

    let name: String
    let uuid: CBUUID
    let expectedProperties: CBCharacteristicProperties
}

private extension CBService {

    func characteristic(modelledBy model: Characteristic) -> CBCharacteristic? {
        let characteristic = self.characteristics?.first { characteristic in
            characteristic.uuid == model.uuid &&
            characteristic.properties.isSuperset(of: model.expectedProperties)
        }

        if let characteristic = characteristic {
            return characteristic
        } else {
            os_log(.error, "No matching CBCharacteristic found for model: %@", model.name)
            return nil
        }
    }
}

private extension CBManagerState {

    var connectionState: LEDPeripheralController.State {
        switch self {
        case .poweredOn:
            return .readyToConnect
        case .poweredOff:
            return .off
        case .unauthorized:
            return .unauthorized
        case .resetting, .unsupported, .unknown:
            fallthrough
        @unknown default:
            return .unknown
        }
    }
}
