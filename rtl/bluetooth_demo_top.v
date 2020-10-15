// bluetooth_demo_top.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module bluetooth_demo_top (
    input clk_25mhz,

    input ftdi_txd,
    output ftdi_rxd,

    // ESP32 ("sd_d" pins in .lpf were renamed to their "wifi_gpio" equivalent)

    output wifi_en,

    input wifi_gpio5,
    input wifi_gpio16,
    input wifi_gpio2,
    input wifi_gpio4,

    output wifi_gpio12,
    output wifi_gpio13,

    input  wifi_txd,
    output wifi_rxd,

    // User interaction

    output [7:0] led,
    input [6:0] btn
);
    // --- PLL (100MHz output) ---

    wire pll_locked;
    wire clk;

    pll pll(
        .clkin(clk_25mhz),
        .clkout0(clk),
        .locked(pll_locked)
    );

    // --- Reset generator ---

    reg [23:0] reset_counter = 0;
    wire reset = !reset_counter[23];

    always @(posedge clk) begin
        if (!pll_locked) begin
            reset_counter <= 0;
        end else if (reset) begin
            reset_counter <= reset_counter + 1;
        end
    end

    // --- LED control (ESP32 + PCB user buttons) ---

    assign wifi_en = 1;

    // UART for console:

    assign wifi_rxd = ftdi_txd;
    assign ftdi_rxd = wifi_txd;

    reg [3:0] esp_sync_ff [0:1];

    // ESP32 inputs:

    wire esp_write_en = esp_sync_ff[1][3];
    wire esp_spi_mosi = esp_sync_ff[1][2];
    wire esp_spi_clk = esp_sync_ff[1][1];
    wire esp_spi_csn = esp_sync_ff[1][0];

    always @(posedge clk) begin
        esp_sync_ff[1] <= esp_sync_ff[0];
        esp_sync_ff[0] <= {wifi_gpio2, wifi_gpio4, wifi_gpio16, wifi_gpio5};
    end

    // ESP32 outputs:

    assign wifi_gpio12 = esp_spi_miso;
    assign wifi_gpio13 = esp_read_needed;

    wire esp_spi_miso;
    wire esp_read_needed;

    spi_led spi_led(
        .clk(clk),
        .reset(reset),

        .spi_csn(esp_spi_csn),
        .spi_clk(esp_spi_clk),
        .spi_mosi(esp_spi_mosi),
        .spi_miso(esp_spi_miso),
        .spi_write_en(esp_write_en),

        .increment(btn_trigger[1]),
        .decrement(btn_trigger[2]),
        .left(btn_trigger[5]),
        .right(btn_trigger[6]),

        .read_needed(esp_read_needed),

        .led(led)
    );

    // Button debouncer:

    wire [6:0] btn_level, btn_trigger, btn_released;

    debouncer #(
        .BTN_COUNT(7)
    ) debouncer (
        .clk(clk),
        .reset(reset),

        .btn(btn),

        .level(btn_level),
        .trigger(btn_trigger),
        .released(btn_released)
    );

endmodule
