`timescale 1ns / 1ps
// =============================================================================
//  Program : sram.v
//  Author  : Chun-Jen Tsai
//  Date    : Sep/21/2023
// -----------------------------------------------------------------------------
//  Description:
//  This module synthesizes an SRAM with output 'data_o' in latch mode.
//  when 'we_i' is enabled, 'data_i' will be feed to 'data_o' before the
//  next clock rising edge.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  None.
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2023,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Yang Ming Chiao Tung Uniersity (NYCU)
//                    Hsinchu, Taiwan.
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// =============================================================================

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
    //output reg                    ready_o,
);

reg [DATA_WIDTH-1 : 0] RAM [N_ENTRIES-1 : 0];

// ------------------------------------
// Read operation
// ------------------------------------
assign data_o = RAM[addr_i];

/*
always@(posedge clk_i)
begin
    if (en_i)
    begin
        data_o <= RAM[addr_i];
        ready_o <= 1;
    end
    else
        ready_o <= 0;
end
*/

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


// from sram.v
/*
module sram_df
#(parameter DATA_WIDTH = 32, N_ENTRIES = 128)
(
    input                           clk_i,
    input                           en_i,
    input                           we_i,
    input  [$clog2(N_ENTRIES)-1: 0] addr_i,
    input  [DATA_WIDTH-1: 0]        data_i,
    output reg [DATA_WIDTH-1: 0]    data_o
);

reg [DATA_WIDTH-1 : 0] RAM [N_ENTRIES-1: 0];

always @(posedge clk_i)
begin
    if (en_i)
    begin
        if (we_i)
        begin
            RAM[addr_i] <= data_i;
            data_o <= data_i;
        end
        else
            data_o <= RAM[addr_i];
    end
end
endmodule
*/