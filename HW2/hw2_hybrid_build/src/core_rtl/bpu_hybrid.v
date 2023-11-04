`timescale 1ns / 1ps
// =============================================================================
//  Program : bpu.v
//  Author  : Jin-you Wu
//  Date    : Jan/19/2019
// -----------------------------------------------------------------------------
//  Description:
//  This is the Branch Prediction Unit (BPU) of the Aquila core (A RISC-V core).
// -----------------------------------------------------------------------------
//  Revision information:
//
//  Aug/15/2020, by Chun-Jen Tsai:
//    Hanlding of JAL in this BPU. In the original code, an additional
//    Unconditional Branch Prediction Unit (UC-BPU) was used to handle
//    the JAL instruction, which seemed redundant.
//
// Aug/16/2023, by Chun-Jen Tsai:
//    Replace the fully associative BHT by the standard Bimodal BHT table.
//    The performance drops a little (1.0 DMIPS -> 0.97 DMIPS), but the resource 
//    usage drops significantly.
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2019,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Chiao Tung Uniersity
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
`include "aquila_config.vh"

// LKH_NUM : Likelihood Entry Number, if bimodal, it should be the same as ENTRY_NUM
// HBITS : History Bits (global or local)
module bpu #( parameter ENTRY_NUM = 256, parameter XLEN = 32, parameter LKH_NUM = 1024, parameter HBITS =  $clog2(LKH_NUM))
(
    // System signals
    input               clk_i,
    input               rst_i,
    input               stall_i,

    // from Program_Counter
    input  [XLEN-1 : 0] pc_i, // Addr of the next instruction to be fetched.

    // from Decode
    input               is_jal_i,
    input               is_cond_branch_i,
    input  [XLEN-1 : 0] dec_pc_i, // Addr of the instr. just processed by decoder.

    // from Execute
    input               exe_is_branch_i,
    input               branch_taken_i,
    input               branch_misprediction_i,
    input  [XLEN-1 : 0] branch_target_addr_i,

    // to Program_Counter
    output              branch_hit_o,
    output              branch_decision_o,
    output [XLEN-1 : 0] branch_target_addr_o,

    // to fetch
    output [XLEN-1 : 0]     branch_cmp_fetch, // bimodal and distri mem update
    output [HBITS-1 : 0]    gshare_cmp_fetch, // global
    output [HBITS-1 : 0]    local_cmp_fetch, // local

    output                  gshare_local_decision,
    output                  bimodal_decision,
    // from exe
    input  [XLEN-1 : 0]     branch_cmp_i,
    input  [HBITS-1 : 0]    gshare_cmp_i,
    input  [HBITS-1 : 0]    local_cmp_i,
    input                   gshare_local_i,
    input                   bimodal_i
);

localparam NBITS = $clog2(ENTRY_NUM);


wire                    we;
wire [XLEN-1 : 0]       branch_inst_tag;
wire [NBITS-1 : 0]      read_addr;
wire [NBITS-1 : 0]      write_addr;

// two-bit saturating counter
reg  [1 : 0]            bimodal_likelihood[ENTRY_NUM : 0];
reg  [1 : 0]            selector_likelihood[ENTRY_NUM : 0];
reg  [1 : 0]            gshare_local_likelihood[LKH_NUM : 0];

// bpu history
reg  [HBITS-1 : 0]      global_history;
wire [HBITS-1 : 0]      local_history;
wire [HBITS-1 : 0]      gshare_local_read;

// likelihood update index
wire [NBITS-1 : 0]      likelihood_idx;
wire [NBITS-1 : 0]      selector_idx;
wire [HBITS-1 : 0]      gshare_local_idx;

// branch_decision
wire                    selector_decision;
wire                    update_selector;
wire                    gshare_local_correct;

// "we" is enabled to add a new entry to the BHT table when
// the decoder sees a branch instruction for the first time.
// CY Hsiang 0220_2020: added "~stall_i" to "we ="
assign branch_cmp_fetch = branch_inst_tag;
assign gshare_cmp_fetch = pc_i[HBITS+1 : 2] ^ global_history;
assign local_cmp_fetch = local_history;

//assign we = ~stall_i & (is_cond_branch_i | is_jal_i) & (branch_inst_tag != dec_pc_i);
assign we = ~stall_i & (is_cond_branch_i | is_jal_i) & (branch_cmp_i != dec_pc_i);

assign read_addr = pc_i[NBITS+1 : 2];
assign write_addr = dec_pc_i[NBITS+1 : 2];

//`define LOCAL
`define GSHARE

`ifdef GSHARE
    assign gshare_local_idx = gshare_cmp_i;
    assign gshare_local_read = gshare_cmp_fetch;
`else
    assign gshare_local_idx = local_cmp_i;
    assign gshare_local_read = local_history;
`endif

assign likelihood_idx = write_addr;
assign selector_idx = write_addr;

assign update_selector = bimodal_i ^ gshare_local_i;
assign gshare_local_correct = (bimodal_i ^ branch_taken_i);
integer idx;
wire test;
assign test = (branch_taken_i == gshare_local_i);


// selector likelihood
always @(posedge clk_i)
begin
    if (rst_i)
    begin
        for (idx = 0; idx < ENTRY_NUM; idx = idx + 1)
            selector_likelihood[idx] <= 2'b0;
    end
    else if (stall_i)
    begin
        for (idx = 0; idx < ENTRY_NUM; idx = idx + 1)
            selector_likelihood[idx] <= selector_likelihood[idx];
    end
    else
    begin
        if (we) // Execute the branch instruction for the first time.
        begin
            selector_likelihood[selector_idx] <= {gshare_local_correct,gshare_local_correct};
        end
        else if (exe_is_branch_i && update_selector)
        begin
            case (selector_likelihood[selector_idx])
                2'b00:  // strongly not taken
                    if (gshare_local_correct)
                        selector_likelihood[selector_idx] <= 2'b01;
                    else
                        selector_likelihood[selector_idx] <= 2'b00;
                2'b01:  // weakly not taken
                    if (gshare_local_correct)
                        selector_likelihood[selector_idx] <= 2'b11;
                    else
                        selector_likelihood[selector_idx] <= 2'b00;
                2'b10:  // weakly taken
                    if (gshare_local_correct)
                        selector_likelihood[selector_idx] <= 2'b11;
                    else
                        selector_likelihood[selector_idx] <= 2'b00;
                2'b11:  // strongly taken
                    if (gshare_local_correct)
                        selector_likelihood[selector_idx] <= 2'b11;
                    else
                        selector_likelihood[selector_idx] <= 2'b10;
            endcase
        end
    end
end

// gshare/local likelihood
always @(posedge clk_i)
begin
    if (rst_i)
    begin
        for (idx = 0; idx < LKH_NUM; idx = idx + 1)
            gshare_local_likelihood[idx] <= 2'b0;
    end
    else if (stall_i)
    begin
        for (idx = 0; idx < LKH_NUM; idx = idx + 1)
            gshare_local_likelihood[idx] <= gshare_local_likelihood[idx];
    end
    else
    begin
        if (we) // Execute the branch instruction for the first time.
        begin
            gshare_local_likelihood[gshare_local_idx] <= {branch_taken_i, branch_taken_i};
        end
        else if (exe_is_branch_i)
        begin
            case (gshare_local_likelihood[gshare_local_idx])
                2'b00:  // strongly not taken
                    if (branch_taken_i)
                        gshare_local_likelihood[gshare_local_idx] <= 2'b01;
                    else
                        gshare_local_likelihood[gshare_local_idx] <= 2'b00;
                2'b01:  // weakly not taken
                    if (branch_taken_i)
                        gshare_local_likelihood[gshare_local_idx] <= 2'b11;
                    else
                        gshare_local_likelihood[gshare_local_idx] <= 2'b00;
                2'b10:  // weakly taken
                    if (branch_taken_i)
                        gshare_local_likelihood[gshare_local_idx] <= 2'b11;
                    else
                        gshare_local_likelihood[gshare_local_idx] <= 2'b00;
                2'b11:  // strongly taken
                    if (branch_taken_i)
                        gshare_local_likelihood[gshare_local_idx] <= 2'b11;
                    else
                        gshare_local_likelihood[gshare_local_idx] <= 2'b10;
            endcase
        end
    end
end


// bimodal likelihood
always @(posedge clk_i)
begin
    if (rst_i)
    begin
        for (idx = 0; idx < ENTRY_NUM; idx = idx + 1)
            bimodal_likelihood[idx] <= 2'b0;
    end
    else if (stall_i)
    begin
        for (idx = 0; idx < ENTRY_NUM; idx = idx + 1)
            bimodal_likelihood[idx] <= bimodal_likelihood[idx];
    end
    else
    begin
        if (we) // Execute the branch instruction for the first time.
        begin
            bimodal_likelihood[likelihood_idx] <= {branch_taken_i, branch_taken_i};
        end
        else if (exe_is_branch_i)
        begin
            case (bimodal_likelihood[likelihood_idx])
                2'b00:  // strongly not taken
                    if (branch_taken_i)
                        bimodal_likelihood[likelihood_idx] <= 2'b01;
                    else
                        bimodal_likelihood[likelihood_idx] <= 2'b00;
                2'b01:  // weakly not taken
                    if (branch_taken_i)
                        bimodal_likelihood[likelihood_idx] <= 2'b11;
                    else
                        bimodal_likelihood[likelihood_idx] <= 2'b00;
                2'b10:  // weakly taken
                    if (branch_taken_i)
                        bimodal_likelihood[likelihood_idx] <= 2'b11;
                    else
                        bimodal_likelihood[likelihood_idx] <= 2'b00;
                2'b11:  // strongly taken
                    if (branch_taken_i)
                        bimodal_likelihood[likelihood_idx] <= 2'b11;
                    else
                        bimodal_likelihood[likelihood_idx] <= 2'b10;
            endcase
        end
    end
end



// ===========================================================================
//  Branch History Table (BHT). Here, we use a direct-mapping cache table to
//  store branch history. Each entry of the table contains two fields:
//  the branch_target_addr and the PC of the branch instruction (as the tag).
//
distri_ram #(.ENTRY_NUM(ENTRY_NUM), .XLEN(XLEN*2))
BPU_BHT(
    .clk_i(clk_i),
    .we_i(we),                  // Write-enabled when the instruction at the Decode
                                //   is a branch and has never been executed before.
    .write_addr_i(write_addr),  // Direct-mapping index for the branch at Decode.
    .read_addr_i(read_addr),    // Direct-mapping Index for the next PC to be fetched.

    .data_i({branch_target_addr_i, dec_pc_i}), // Input is not used when 'we' is 0.
    .data_o({branch_target_addr_o, branch_inst_tag})
);

// ===========================================================================
//  Outputs signals
//
assign gshare_local_decision = gshare_local_likelihood[gshare_local_read][1];
assign bimodal_decision = bimodal_likelihood[read_addr][1];
assign selector_decision = selector_likelihood[read_addr][1];

assign branch_hit_o = (branch_inst_tag == pc_i);
assign branch_decision_o = selector_decision ? gshare_local_likelihood[gshare_local_read][1] : bimodal_likelihood[read_addr][1];

`ifdef GSHARE
always@(posedge clk_i)
begin
    if(rst_i) global_history <= 0;
    else if((~stall_i) & exe_is_branch_i) global_history = {global_history[HBITS-2:0], branch_taken_i};
end
`endif

`ifdef LOCAL
distri_lht_ram #(.ENTRY_NUM(LKH_NUM), .XLEN(HBITS), .AWDTH(HBITS)) BPU_LHT(
    .clk_i(clk_i),
    .we_i((~stall_i) & exe_is_branch_i),   // Write-enabled when the instruction at the Decode

    .write_addr_i(dec_pc_i[HBITS+1 : 2]),  // Direct-mapping index for the branch at Decode.
    .read_addr_i(pc_i[HBITS+1 : 2]),    // Direct-mapping Index for the next PC to be fetched.

    .data_i(branch_taken_i),
    .data_o(local_history)
);
`endif

endmodule
