# main.py
#
# Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
#
# SPDX-License-Identifier: MIT

import bluetooth
from machine import Pin
from ble_advertising import advertising_payload
from ble_peripheral import BLESimplePeripheral

# ESP32 GPIO

spi_csn = Pin(5, Pin.OUT)
spi_clk = Pin(16, Pin.OUT)
spi_mosi = Pin(4, Pin.OUT)
spi_miso = Pin(12, Pin.IN)
spi_write_en = Pin(2, Pin.OUT)

read_needed = Pin(13, Pin.IN)

# ESP32 -> FPGA

def fpga_write_leds(leds):
    spi_clk(0)
    spi_write_en(1)
    spi_csn(0)

    for _ in range(8):
        spi_mosi((leds & 0x80) >> 7)
        spi_clk(1)
        spi_clk(0)
        leds <<= 1;

    spi_csn(1)

# ESP32 <- FPGA

def fpga_read_leds():
    spi_clk(0)
    spi_write_en(0)
    spi_csn(0)

    leds = 0;
    for _ in range(8):
        leds <<= 1
        leds |= spi_miso.value()
        spi_clk(1)
        spi_clk(0)

    spi_csn(1)

    return leds

# Main loop

def demo():
    spi_csn(1)

    ble = bluetooth.BLE()
    peripheral = BLESimplePeripheral(ble)

    def bt_send():
        leds = fpga_read_leds()
        peripheral.send(bytes([leds]))
        print("LED byte sent: ", leds)

    def bt_receive(bytes):
        leds = bytes[0]
        print("LED byte received: ", leds)
        fpga_write_leds(leds);
        bt_send()

    peripheral.on_write(bt_receive)

    while True:
        if peripheral.is_connected() and read_needed.value():
            print("Change triggered by FPGA..")
            bt_send()

demo()
