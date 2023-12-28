`timescale 1ns / 1ps
`include "aquila_config.vh"

module data_feeder #( parameter XLEN = 32, parameter BUF_ADDR_LEN = 12, parameter BRAM_ADDR_LEN = 10)
(
    input                           clk_i,
    input                           rst_i,

// from aquila
// aquila : write to counter register
// aquila : read from ready_flag, write 0 to ready flag
// aquila : read from result register
// aquila : write vector and weight to sram
    input                           S_DEVICE_strobe_i, 
    input [BUF_ADDR_LEN-1 : 0]      S_DEVICE_addr_i,
    input                           S_DEVICE_rw_i,
    input [XLEN/8-1 : 0]            S_DEVICE_byte_enable_i,
    input [XLEN-1 : 0]              S_DEVICE_data_i,

// to aquila
    output reg                      S_DEVICE_ready_o,
    output [XLEN-1 : 0]             S_DEVICE_data_o,

// to floating point IP
    output                          a_valid,
    output [XLEN-1 : 0]             a_data,
    input                           a_ready,
    output                          b_valid,
    output [XLEN-1 : 0]             b_data,
    input                           b_ready,
    output                          c_valid,
    output [XLEN-1 : 0]             c_data,
    input                           c_ready,

// from floating point IP
    input                           r_valid,
    input [XLEN-1 : 0]              r_data_i,
    output                          r_ready
);


// =========================================
//  data feeder registers 
// =========================================
wire df_en;
wire [XLEN-1 : 0]       df_o;
reg [XLEN-1 : 0]        data_ready;          // 0xC4000000
reg [XLEN-1 : 0]        data_feeder_counter; // 0xC4000004
(* mark_debug="true" *) reg [XLEN-1 : 0]        dsa_result;          // 0xC4000008
(* mark_debug="true" *)reg [XLEN-1 : 0]        dsa_trigger;         // 0xC400000C
reg [XLEN-1 : 0]        dsa_trigger_r;
(* mark_debug="true" *) reg [XLEN-1 : 0]        df_count_a;
(* mark_debug="true" *) reg [XLEN-1 : 0]        df_count_b;
(* mark_debug="true" *) reg [XLEN-1 : 0]        df_count_c;
wire df_ready_sel, df_count_sel, df_trigger_sel;

assign df_ready_sel = (S_DEVICE_addr_i[1:0] == 2'b00);
assign df_count_sel = (S_DEVICE_addr_i[1:0] == 2'b01);
assign df_trigger_sel = (S_DEVICE_addr_i[1:0] == 2'b11);

// =========================================
//  bram control signals 
// =========================================
//(* mark_debug="true" *)wire                    bram_en;
wire [1:0]                  bram_we_sel;           // write to which bram?
wire [BRAM_ADDR_LEN-1 : 0]  bram_addr_a, bram_addr_b;
wire [XLEN-1 : 0]           vector_buffer_o;
wire [XLEN-1 : 0]           weight_buffer_o;
wire [XLEN-1 : 0]           bram_o;

// =========================================
//  data feeder read/write operation 
// =========================================
assign df_en = (S_DEVICE_strobe_i & (!S_DEVICE_addr_i[11:10]));
assign df_o = df_ready_sel ? data_ready : df_count_sel ? data_feeder_counter : df_trigger_sel ? dsa_trigger : dsa_result;
assign S_DEVICE_data_o = (!S_DEVICE_addr_i[11:10]) ? df_o : bram_o;

always@(posedge clk_i)
begin
    if(rst_i)
    begin
        data_ready <= 0;
        data_feeder_counter <= 32'hFFFFFFFF; // different from df_counter, so ready flag will be zero
        dsa_trigger <= 0;
    end
    else if(df_en && S_DEVICE_rw_i)
    begin
        if(df_ready_sel) 
            data_ready <= S_DEVICE_data_i;
        else if(df_count_sel) 
            data_feeder_counter <= S_DEVICE_data_i;
        else if(df_trigger_sel) 
            dsa_trigger <= S_DEVICE_data_i;
    end
    else if(df_count_c == data_feeder_counter) 
    begin 
        data_ready <= 32'h00000001;
        dsa_trigger <= 32'h00000000;
    end
    else data_ready <= data_ready;
end

always@(posedge clk_i)
begin
    if(rst_i) 
        dsa_result <= 0;
    else if(df_count_c == data_feeder_counter) 
        dsa_result <= c_data;
    else 
        dsa_result <= dsa_result;
end

always@(posedge clk_i)
begin
    if(rst_i) 
        S_DEVICE_ready_o <= 1'b0;
    else if(S_DEVICE_strobe_i) 
        S_DEVICE_ready_o <= 1'b1;
    else 
        S_DEVICE_ready_o <= 1'b0;
end

// =========================================
//  bram write/read 
// =========================================
//assign bram_en = S_DEVICE_strobe_i & (|S_DEVICE_addr_i[11:10]);
assign bram_we_sel = (S_DEVICE_addr_i[10] & S_DEVICE_rw_i)? 2'b01 : (S_DEVICE_addr_i[11] & S_DEVICE_rw_i)? 2'b10 : 2'b00;
assign bram_addr_a = (dsa_trigger_r | dsa_trigger) ? df_count_a[BRAM_ADDR_LEN-1:0] : S_DEVICE_addr_i[BRAM_ADDR_LEN-1:0];
assign bram_addr_b = (dsa_trigger_r | dsa_trigger) ? df_count_b[BRAM_ADDR_LEN-1:0] : S_DEVICE_addr_i[BRAM_ADDR_LEN-1:0];
assign bram_o = S_DEVICE_addr_i[10] ? vector_buffer_o : weight_buffer_o;

// Base Address : 0xC4001000
sram_be #(.DATA_WIDTH(32), .N_ENTRIES(1024))
Vector_SRAM_BE(
    .clk_i(clk_i),
    .en_i(S_DEVICE_strobe_i & (S_DEVICE_addr_i[10])),
    .we_i(bram_we_sel[0]),
    .be_i(S_DEVICE_byte_enable_i),
    .addr_i(bram_addr_a),
    .data_i(S_DEVICE_data_i),
    .data_o(vector_buffer_o)
);

// Base Address : 0xC4002000
sram_be #(.DATA_WIDTH(32), .N_ENTRIES(1024))
Weight_SRAM_BE(
    .clk_i(clk_i),
    .en_i(S_DEVICE_strobe_i & (S_DEVICE_addr_i[11])),
    .we_i(bram_we_sel[1]),
    .be_i(S_DEVICE_byte_enable_i),
    .addr_i(bram_addr_b),
    .data_i(S_DEVICE_data_i),
    .data_o(weight_buffer_o)
);


always@(posedge clk_i)
begin
    if(rst_i) 
        dsa_trigger_r <= 32'h0;
    else 
        dsa_trigger_r <= dsa_trigger;
end

always@(posedge clk_i)
begin
    if(rst_i | !(dsa_trigger)) 
        df_count_a <= 0;
    else if(dsa_trigger && (df_count_a < data_feeder_counter) && a_ready && a_valid) 
        df_count_a = df_count_a + 1;
end

always@(posedge clk_i)
begin
    if(rst_i | !(dsa_trigger)) 
        df_count_b <= 0;
    else if(dsa_trigger && (df_count_b < data_feeder_counter) && b_ready && b_valid) 
        df_count_b = df_count_b + 1;
end
always@(posedge clk_i)
begin
    if(rst_i | !(dsa_trigger)) 
        df_count_c <= 0;
    else if(dsa_trigger && (df_count_c < data_feeder_counter) && r_valid) 
        df_count_c = df_count_c + 1;
end

reg [XLEN-1 : 0] a_data_r;
reg [XLEN-1 : 0] b_data_r;
reg [XLEN-1 : 0] c_data_r;
(* mark_debug="true" *) reg a_valid_r;
(* mark_debug="true" *) reg b_valid_r;
(* mark_debug="true" *) reg c_valid_r;
always@(posedge clk_i)
begin
    if(rst_i) 
        c_data_r <= 32'h0;
    else if((!dsa_trigger_r)) 
        c_data_r <= 32'h0;
    else if((df_count_c <= data_feeder_counter) && (r_valid)) 
        c_data_r <= r_data_i;
    else 
        c_data_r <= c_data_r;
end


/*
always@(posedge clk_i) 
begin
    if(rst_i) 
        c_valid_r <= 0;
    else if(dsa_trigger && !dsa_trigger_r) 
        c_valid_r <= 1;
    else if(dsa_trigger && df_count_c == data_feeder_counter) 
        c_valid_r <= 0;
    else 
        c_valid_r = r_valid;
end
*/


always@(posedge clk_i) 
begin
    if(rst_i)
        c_valid_r <= 1'b0;
    else if(dsa_trigger && (!dsa_trigger_r)) 
        c_valid_r <= 1'b1;
    else if(r_valid && (df_count_c < data_feeder_counter - 1)) 
        c_valid_r <= 1'b1;
    else
        c_valid_r = 1'b0;;
end


always@(posedge clk_i)
begin
    a_data_r = vector_buffer_o;
    b_data_r = weight_buffer_o;
end


always@(posedge clk_i)
begin
    if(rst_i) 
        a_valid_r <= 0;
    else if(a_ready & a_valid_r)
        a_valid_r <= 1'b0;
    else if((dsa_trigger) && (df_count_a != data_feeder_counter))
        a_valid_r = 1;
    else 
        a_valid_r <= a_valid_r;
end

always@(posedge clk_i)
begin
    if(rst_i) 
        b_valid_r <= 1'b0;
    else if(b_valid_r && b_ready)
        b_valid_r <= 1'b0;
    else if((dsa_trigger) && (df_count_b != data_feeder_counter))
        b_valid_r <= 1'b1;
    else
        b_valid_r <= b_valid_r;
end

//assign a_valid = dsa_trigger_r & (df_count_a != data_feeder_counter);
//assign b_valid = dsa_trigger_r & (df_count_b != data_feeder_counter);
assign a_valid = a_valid_r;
assign b_valid = b_valid_r;
assign c_valid = c_valid_r;
assign a_data = a_data_r;
assign b_data = b_data_r;
assign c_data = c_data_r;
assign r_ready = dsa_trigger;

endmodule