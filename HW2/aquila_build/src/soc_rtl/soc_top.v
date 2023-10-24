`timescale 1ns / 1ps
// =============================================================================
//  Program : soc_top.v
//  Author  : Chun-Jen Tsai
//  Date    : Feb/16/2020
// -----------------------------------------------------------------------------
//  Description:
//  This is the top-level Aquila IP wrapper for an AXI-based processor SoC.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  This module is based on the soc_top.v module written by Jin-you Wu
//  on Feb/28/2019. The original module was a stand-alone top-level module
//  for an SoC. This rework makes it a module embedded inside an AXI IP.
//
//  Jan/12/2020, by Chun-Jen Tsai:
//    Added a on-chip Tightly-Coupled Memory (TCM) to the aquila SoC.
//
//  Sep/12/2022, by Chun-Jen Tsai:
//    Fix an issue of missing reset signal across clock domains.
//    Use the clock wizard to generate the Aquila clock on Arty.
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

module soc_top #( parameter XLEN = 32, parameter CLSIZE = `CLP )
(
    input           sysclk_i,
    input           resetn_i,

    // uart
    input           uart_rx,
    output          uart_tx,

    // buttons & leds
    input  [0 : `USRP-1]  usr_btn,
    output [0 : `USRP-1]  usr_led
);

wire usr_reset;
wire ui_clk, ui_rst;
wire clk, rst;

// --------- External memory interface -----------------------------------------
// Instruction memory ports (Not used for HW#0 ~ HW#2)
wire                IMEM_strobe;
wire [XLEN-1 : 0]   IMEM_addr;
wire                IMEM_done = 0;
wire [CLSIZE-1 : 0] IMEM_data = {CLSIZE{1'b0}};

// Data memory ports (Not used for HW#0 ~ HW#2)
wire                DMEM_strobe;
wire [XLEN-1 : 0]   DMEM_addr;
wire                DMEM_rw;
wire [CLSIZE-1 : 0] DMEM_wt_data;
wire                DMEM_done = 0;
wire [CLSIZE-1 : 0] DMEM_rd_data = {CLSIZE{1'b0}};

// --------- I/O device interface ----------------------------------------------
// Device bus signals
wire                dev_strobe;
wire [XLEN-1 : 0]   dev_addr;
wire                dev_we;
wire [XLEN/8-1 : 0] dev_be;
wire [XLEN-1 : 0]   dev_din;
wire [XLEN-1 : 0]   dev_dout;
wire                dev_ready;

// DSA device signals (Not used for HW#0 ~ HW#4)
wire                dsa_sel;
wire [XLEN-1 : 0]   dsa_dout;
wire                dsa_ready;

// Uart
wire                uart_sel;
wire [XLEN-1 : 0]   uart_dout;
wire                uart_ready;

// Profiler
wire [XLEN-1 : 0]   dev_in;
reg                 program_end;
wire [XLEN/8-1 : 0] dev_be_o;
reg  [XLEN/8-1 : 0] pf_be;
wire                dev_we_o;
wire                dev_strobe_o;
wire                xstate_ack;
// --------- System Clock Generator --------------------------------------------
// Generates a 41.66667 MHz system clock from the 100MHz oscillator on the PCB.
assign usr_reset = ~resetn_i;

clk_wiz_0 Clock_Generator(
    .clk_in1(sysclk_i),  // Board oscillator clock
    .clk_out1(clk)       // System clock for the Aquila SoC
);

// -----------------------------------------------------------------------------
// Synchronize the system reset signal (usr_reset) across the clock domains
//   to the Aquila SoC domains (rst).
//
// For the Aquila Core, the reset (rst) should lasts for at least 5 cycles
//   to initialize all the pipeline registers.
//
localparam SR_N = 8;
reg [SR_N-1:0] sync_reset = {SR_N{1'b1}};
assign rst = sync_reset[SR_N-1];

always @(posedge clk) begin
    if (usr_reset)
        sync_reset <= {SR_N{1'b1}};
    else
        sync_reset <= {sync_reset[SR_N-2 : 0], 1'b0};
end

// -----------------------------------------------------------------------------
//  Aquila processor core.
//
aquila_top Aquila_SoC
(
    .clk_i(clk),
    .rst_i(rst),          // level-sensitive reset signal.
    .base_addr_i(32'b0),  // initial program counter.

    // External instruction memory ports.
    .M_IMEM_strobe_o(IMEM_strobe),
    .M_IMEM_addr_o(IMEM_addr),
    .M_IMEM_done_i(IMEM_done),
    .M_IMEM_data_i(IMEM_data),

    // External data memory ports.
    .M_DMEM_strobe_o(DMEM_strobe),
    .M_DMEM_addr_o(DMEM_addr),
    .M_DMEM_rw_o(DMEM_rw),
    .M_DMEM_data_o(DMEM_wt_data),
    .M_DMEM_done_i(DMEM_done),
    .M_DMEM_data_i(DMEM_rd_data),

    // I/O device ports.
    .M_DEVICE_strobe_o(dev_strobe),
    .M_DEVICE_addr_o(dev_addr),
    .M_DEVICE_rw_o(dev_we),
    .M_DEVICE_byte_enable_o(dev_be),
    .M_DEVICE_data_o(dev_din),
    .M_DEVICE_data_ready_i(dev_ready),
    .M_DEVICE_data_i(dev_dout)
);

// -----------------------------------------------------------------------------
//  Device address decoder.
//
//       [0] 0xC000_0000 - 0xC0FF_FFFF : UART device
//       [1] 0xC200_0000 - 0xC2FF_FFFF : DSA device
assign uart_sel  = (dev_addr[XLEN-1:XLEN-8] == 8'hC0);
assign dsa_sel   = (dev_addr[XLEN-1:XLEN-8] == 8'hC2);
assign dev_dout  = (uart_sel)? uart_dout : (dsa_sel)? dsa_dout : {XLEN{1'b0}};
assign dev_ready = (uart_sel)? uart_ready : (dsa_sel)? dsa_ready : {XLEN{1'b0}};

// ----------------------------------------------------------------------------
//  UART Controller with a simple memory-mapped I/O interface.
//
`define BAUD_RATE	115200

uart #(.BAUD(`SOC_CLK/`BAUD_RATE))
UART(
    .clk(clk),
    .rst(rst),

    .EN(dev_strobe_o),
    .ADDR(dev_addr[3:2]),
    .WR(dev_we_o),
    .BE(dev_be_o),
    .DATAI(dev_in),
    .DATAO(uart_dout),
    .READY(uart_ready),

    .RXD(uart_rx),
    .TXD(uart_tx)

    // new
    ,.xstate_ack(xstate_ack)
);




// =============================================================================
// new 
// whether to display from the program or the program has ended 
// for now only display 3 lines < test >
reg [0 : 102*8 - 1] line1 = {"\015\012====================================== five hotspot functions ======================================"};
reg [0 : 39*8 - 1]  line2 = {"\015\012function			cpu cycle		alu		mem		stall"};
reg [0 : 65*8 - 1]  line3 = {"\015\012core_list_reverse		0000000000		0000000000	0000000000	0000000000"};
reg [0 : 63*8 - 1]  line4 = {"\015\012core_list_find			0000000000		0000000000	0000000000	0000000000"};
reg [0 : 69*8 - 1]  line5 = {"core_state_transition		0000000000		0000000000	0000000000	0000000000"};
reg [0 : 75*8 - 1]  line6 = {"matrix_mul_matrix_bitextract	0000000000		0000000000	0000000000	0000000000"};
reg [0 : 55*8 - 1]  line7 = {"crcu8				0000000000		0000000000	0000000000	0000000000"};
reg [0 : 102*8 - 1] line8 = {"===================================================================================================="};

localparam LINE1_SIZE = 102, LINE2_SIZE = 39, LINE3_SIZE = 65, LINE4_SIZE = 63; 
localparam MEM_SIZE = LINE1_SIZE + LINE2_SIZE + LINE3_SIZE;
integer i;
reg [7:0] data[0:MEM_SIZE-1];
reg [10:0] counter = 0;
reg first_byte = 0, first_byte_next = 0;
wire       is_done;


always@(posedge clk)
begin
    if(rst)
        program_end = 0;
    else if(dev_din == 3)
        program_end = 1;
end

always@(posedge clk)
begin
    if(rst)
    begin
        for(i = 0; i < LINE1_SIZE; i = i + 1) data[i] <= line1[i*8 +: 8];
        for(i = 0; i < LINE2_SIZE; i = i + 1) data[i+LINE1_SIZE] <= line2[i*8 +: 8];
        for(i = 0; i < LINE3_SIZE; i = i + 1) data[i+LINE1_SIZE+LINE2_SIZE] <= line3[i*8 +: 8];
    end
end

//  handle the program ended byte '0x03'
always@(posedge clk)
begin
    if(rst) first_byte_next <= 0;
    else if(program_end & xstate_ack)
        first_byte_next = 1;
    else
        first_byte_next = first_byte_next;
end

always@(posedge clk)begin
    if(rst) first_byte <= 0;
    else first_byte <= first_byte_next;
end


always@(posedge clk)
begin
    if(rst) counter <= 0;
    else if(program_end && xstate_ack && first_byte) counter <= counter + 1;
    if(counter > MEM_SIZE) counter <= counter;
end


assign dev_in = program_end ? data[counter] : dev_din;
assign dev_be_o = program_end ? 2'b10 : dev_be;
assign dev_we_o = program_end ? 1 : dev_we;
assign dev_strobe_o = program_end && is_done ? 0 : program_end ? 1 : dev_strobe & uart_sel;
assign is_done = program_end && (counter > MEM_SIZE);


/*
wire [XLEN*2-1 : 0] core_list_reverse_count;
wire [XLEN*2-1 : 0] core_list_find_count;
wire [XLEN*2-1 : 0] core_state_transition_count;
wire [XLEN*2-1 : 0] matrix_mul_matrix_bitextract_count;
wire [XLEN*2-1 : 0] crcu8_count;

profiler #(.XLEN(XLEN)) Profiler(   
    
    // to profiler
    .clk_i(clk),
    .rst_i(rst),
    .stall_i(stall_i),
    .flush_i(flush_i),
    .pc_i(pc_i),

    // from profiler
    .core_list_reverse_o(core_list_reverse_count),
    .core_list_find_o(core_list_find_count),
    .core_state_transition_o(core_state_transition_count),
    .matrix_mul_matrix_bitextract_o(matrix_mul_matrix_bitextract_count),
    .crcu8_o(crcu8_count)
);
*/

endmodule
