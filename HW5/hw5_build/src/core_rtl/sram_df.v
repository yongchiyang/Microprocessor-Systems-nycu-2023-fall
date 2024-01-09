`timescale 1ns / 1ps

// from sram_dp.v
module sram_be
#(parameter DATA_WIDTH = 32, N_ENTRIES = 1024, ADDRW = $clog2(N_ENTRIES))
(
    input                         clk_i,
    input                         en_i,
    input                         we_i,
    input  [DATA_WIDTH/8-1 : 0]   be_i,
    input  [ADDRW-1 : 0]          addr_i,
    input  [DATA_WIDTH-1 : 0]     data_i,
    output [DATA_WIDTH-1 : 0]     data_o
);

reg [DATA_WIDTH-1 : 0] RAM [N_ENTRIES-1 : 0];

// ------------------------------------
// Read operation
// ------------------------------------
assign data_o = RAM[addr_i];


// ------------------------------------
// Write operations
// ------------------------------------
integer idx;

always@(posedge clk_i)
begin
    if (en_i)
    begin
        if (we_i)
            for (idx = 0; idx < DATA_WIDTH/8; idx = idx + 1)
                if (be_i[idx]) RAM[addr_i][(idx<<3) +: 8] <= data_i[(idx<<3) +: 8];
    end
end

endmodule