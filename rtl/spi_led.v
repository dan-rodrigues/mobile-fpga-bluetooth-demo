// spi_led.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module spi_led #(
    parameter integer WIDTH = 8
) (
    input clk,
    input reset,

    input spi_csn,
    input spi_clk,
    input spi_mosi,
    output spi_miso,
    input spi_write_en,

    input increment,
    input decrement,
    input left,
    input right,

    output reg read_needed,
    output reg [WIDTH - 1:0] led,
);
    localparam LEDS_WIDTH = WIDTH - 1;

    reg spi_clk_r;
    reg spi_csn_r;

    reg [LEDS_WIDTH:0] send_buffer;
    reg [LEDS_WIDTH:0] receive_buffer;

    assign spi_miso = send_buffer[LEDS_WIDTH];

    wire spi_csn_rose = spi_csn && !spi_csn_r;
    wire spi_csn_fell = !spi_csn && spi_csn_r;
    wire spi_clk_rose = spi_clk && !spi_clk_r;

    always @(posedge clk) begin
        if (reset) begin
            led <= 0;
            spi_clk_r <= 0;
            spi_csn_r <= 1;
            read_needed <= 0;
        end else begin
            spi_clk_r <= spi_clk;
            spi_csn_r <= spi_csn;

            if (spi_csn_fell) begin
                send_buffer <= led;
                read_needed <= 0;
            end else if (!spi_csn && spi_clk_rose) begin
                send_buffer <= send_buffer << 1;
                receive_buffer <= {spi_mosi, receive_buffer[7:1]};
            end

            if (spi_write_en && spi_csn_rose) begin
                led <= receive_buffer;
            end else if (spi_csn) begin
                if (increment) begin
                    led <= led + 1;
                end else if (decrement) begin
                    led <= led - 1;
                end else if (left) begin
                    led <= led << 1;
                end else if (right) begin
                    led <= led >> 1;
                end

                read_needed <= read_needed | increment | decrement | left | right;
            end
        end
    end

endmodule
