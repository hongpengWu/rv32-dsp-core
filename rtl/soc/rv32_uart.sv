`timescale 1ns / 1ps

// Minimal memory-mapped UART for the RV32I/RT-Thread Nano platform.
//
// Register map (BASE_ADDR + offset):
//   0x00 TXDATA  write low byte to transmit; read returns low byte
//   0x04 STATUS  bit 0 = transmitter ready, bit 1 = transmitter busy
//   0x08 RXDATA  read returns zero (no receive pin in the PL-only image)
//   0x0c RXSTAT  bit 0 = receive data available (always zero)
//
// TX is a conventional 8-N-1 stream.  A write is accepted only while the
// transmitter is idle; software can poll STATUS[0] before writing the next
// byte.  tx_write_pulse/data are exported for simulation and optional board
// instrumentation; they are not needed by the serial pin itself.
module rv32_uart #(
    parameter logic [31:0] BASE_ADDR = 32'h1000_0000,
    parameter integer CLK_HZ = 80_000_000,
    parameter integer BAUD = 115_200
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        req_valid,
    input  logic        req_write,
    input  logic [31:0] req_addr,
    input  logic [3:0]  req_wstrb,
    input  logic [31:0] req_wdata,
    output logic        rsp_valid,
    output logic [31:0] rsp_rdata,
    output logic        tx,
    output logic        tx_busy,
    output logic        tx_write_pulse,
    output logic [7:0]  tx_write_data
);
    localparam integer BAUD_DIV = (CLK_HZ / BAUD < 1) ? 1 : (CLK_HZ / BAUD);
    localparam logic [31:0] TXDATA_ADDR = BASE_ADDR + 32'h00;
    localparam logic [31:0] STATUS_ADDR = BASE_ADDR + 32'h04;
    localparam logic [31:0] RXDATA_ADDR = BASE_ADDR + 32'h08;
    localparam logic [31:0] RXSTAT_ADDR = BASE_ADDR + 32'h0c;

    logic [9:0]  tx_shift;
    logic [3:0]  tx_bit;
    logic [31:0] baud_count;
    logic [31:0] read_data;
    logic        req_hit;

    assign req_hit = req_valid &&
                     ((req_addr == TXDATA_ADDR) ||
                      (req_addr == STATUS_ADDR) ||
                      (req_addr == RXDATA_ADDR) ||
                      (req_addr == RXSTAT_ADDR));

    assign tx = tx_busy ? tx_shift[0] : 1'b1;

    always_comb begin
        case (req_addr)
            TXDATA_ADDR: read_data = {24'd0, tx_write_data};
            STATUS_ADDR: read_data = {30'd0, tx_busy, ~tx_busy};
            RXDATA_ADDR: read_data = 32'd0;
            RXSTAT_ADDR: read_data = 32'd0;
            default:     read_data = 32'd0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            rsp_valid      <= 1'b0;
            rsp_rdata      <= 32'd0;
            tx_busy        <= 1'b0;
            tx_shift       <= 10'h3ff;
            tx_bit         <= 4'd0;
            baud_count     <= 32'd0;
            tx_write_pulse <= 1'b0;
            tx_write_data  <= 8'd0;
        end else begin
            rsp_valid      <= req_hit && !req_write;
            rsp_rdata      <= req_hit && !req_write ? read_data : 32'd0;
            tx_write_pulse <= 1'b0;

            if (req_hit && req_write && req_addr == TXDATA_ADDR &&
                req_wstrb[0] && !tx_busy) begin
                tx_write_data  <= req_wdata[7:0];
                tx_write_pulse <= 1'b1;
                // 8 data bits, one start bit (0), one stop bit (1).
                tx_shift      <= {1'b1, req_wdata[7:0], 1'b0};
                tx_bit         <= 4'd0;
                baud_count     <= 32'd0;
                tx_busy        <= 1'b1;
            end else if (tx_busy) begin
                if (baud_count == BAUD_DIV - 1) begin
                    baud_count <= 32'd0;
                    if (tx_bit == 4'd9) begin
                        tx_busy  <= 1'b0;
                        tx_bit   <= 4'd0;
                        tx_shift <= 10'h3ff;
                    end else begin
                        tx_bit   <= tx_bit + 4'd1;
                        tx_shift <= {1'b1, tx_shift[9:1]};
                    end
                end else begin
                    baud_count <= baud_count + 32'd1;
                end
            end
        end
    end
endmodule
