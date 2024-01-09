`timescale 1ns / 1ps
`include "aquila_config.vh"

module data_feeder #( parameter XLEN = 32, parameter BUF_ADDR_LEN = 12, parameter BRAM_ADDR_LEN = 10)
(
    input                           clk_i,
    input                           rst_i,

    // from aquila :
    // write to counter register
    // write to trigger register
    // read from ready_flag, write 0 to ready flag
    // read from result register
    // write vector and weight to sram
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
    //input                           a_ready,
    output                          b_valid,
    output [XLEN-1 : 0]             b_data,
    //input                           b_ready,
    output                          c_valid,
    output [XLEN-1 : 0]             c_data,
    //input                           c_ready,

    // from floating point IP
    input                           r_valid,
    input [XLEN-1 : 0]              r_data_i
    //output                          r_ready
);


// =========================================
//  data feeder registers 
// =========================================
wire df_en;
wire [XLEN-1 : 0]       df_o;
reg [XLEN-1 : 0]        data_ready;          // 0xC4000000
reg [XLEN-1 : 0]        data_feeder_counter; // 0xC4000004
(* mark_debug="true" *) reg [XLEN-1 : 0]        dsa_result;          // 0xC4000008
(* mark_debug="true" *) reg [XLEN-1 : 0]        dsa_trigger;         // 0xC400000C
(* mark_debug="true" *) reg [XLEN-1 : 0]        dsa_vec_base;         // 0xC4000010
(* mark_debug="true" *) reg [XLEN-1 : 0]        dsa_vec_top;         // 0xC4000014

reg [XLEN-1 : 0]        dsa_trigger_r;
(* mark_debug="true" *) reg [XLEN-1 : 0]        df_count_a;
(* mark_debug="true" *) reg [XLEN-1 : 0]        df_count_b;
(* mark_debug="true" *) reg [XLEN-1 : 0]        df_count_c;
wire df_ready_sel, df_count_sel, df_trigger_sel;
wire df_vec_base_sel, df_vec_top_sel;

// =========================================
//  bram control signals 
// =========================================
wire [2:0]                  bram_we_sel;           // write to which bram?
wire [2:0]                  bram_sel;
(* mark_debug="true" *) wire [BRAM_ADDR_LEN-1 : 0]  bram_addr_a;
(* mark_debug="true" *) wire [BRAM_ADDR_LEN-1 : 0]  bram_addr_b [1:0];
(* mark_debug="true" *) wire [XLEN-1 : 0]           vector_buffer_o;
(* mark_debug="true" *) wire [XLEN-1 : 0]           weight_buffer_o [1:0];
(* mark_debug="true" *) wire [XLEN-1 : 0]           b_weight;
(* mark_debug="true" *) wire [XLEN-1 : 0]           bram_o;
(* mark_debug="true" *) reg [XLEN-1 : 0]            R1, R2, R3;

(* mark_debug="true" *) reg [XLEN-1 : 0] compute_lat;


// =========================================
//  data feeder read/write operation 
// =========================================
assign df_ready_sel = (S_DEVICE_addr_i[2:0] == 3'b000);
assign df_count_sel = (S_DEVICE_addr_i[2:0] == 3'b001);
assign df_trigger_sel = (S_DEVICE_addr_i[2:0] == 3'b011);
assign df_vec_base_sel = (S_DEVICE_addr_i[2:0] == 3'b100);
assign df_vec_top_sel = (S_DEVICE_addr_i[2:0] == 3'b101);

assign df_en = (S_DEVICE_strobe_i & (!S_DEVICE_addr_i[11:10]));
assign df_o = df_ready_sel ? data_ready : 
              df_count_sel ? data_feeder_counter : 
              df_trigger_sel ? dsa_trigger : 
              df_vec_base_sel ? dsa_vec_base :
              df_vec_top_sel ? dsa_vec_top : dsa_result;

assign S_DEVICE_data_o = (!S_DEVICE_addr_i[11:10]) ? df_o : bram_o;


// =========================================
//  bram write/read 
// =========================================
assign bram_sel[0] = S_DEVICE_addr_i[10] & ~S_DEVICE_addr_i[11];
assign bram_sel[1] = S_DEVICE_addr_i[11] & ~S_DEVICE_addr_i[10];
assign bram_sel[2] = S_DEVICE_addr_i[10] & S_DEVICE_addr_i[11];
assign bram_addr_a = (dsa_trigger_r | dsa_trigger) ? df_count_a[BRAM_ADDR_LEN-1:0] : S_DEVICE_addr_i[BRAM_ADDR_LEN-1:0];
assign bram_addr_b[0] = (dsa_trigger_r[0] | dsa_trigger[0]) ? df_count_b[BRAM_ADDR_LEN-1:0] : S_DEVICE_addr_i[BRAM_ADDR_LEN-1:0];
assign bram_addr_b[1] = (dsa_trigger_r[1] | dsa_trigger[1]) ? df_count_b[BRAM_ADDR_LEN-1:0] : S_DEVICE_addr_i[BRAM_ADDR_LEN-1:0];
assign bram_o = (& S_DEVICE_addr_i[11:10]) ? weight_buffer_o[1] : (S_DEVICE_addr_i[10]) ? vector_buffer_o : weight_buffer_o[0];

assign a_valid = 1'b1;
assign b_valid = 1'b1;
assign c_valid = 1'b1;
assign a_data = (df_count_a == dsa_vec_top) ? 32'h3f800000 : vector_buffer_o;
assign b_weight = dsa_trigger[0] ? weight_buffer_o[0] : weight_buffer_o[1];
assign b_data = (df_count_b < data_feeder_counter) ? b_weight :
                (df_count_b == data_feeder_counter + 1) ? R1 : 
                (df_count_b == data_feeder_counter + 4) ? R3 : 32'h00000000;
assign c_data = (dsa_trigger_r && dsa_trigger && df_count_c > 2) ? r_data_i : 32'h00000000;


// =========================================
//  data feeder read/write operation 
// =========================================
always@(posedge clk_i)
begin
    if(rst_i) 
        S_DEVICE_ready_o <= 1'b0;
    else if(S_DEVICE_strobe_i) 
        S_DEVICE_ready_o <= 1'b1;
    else 
        S_DEVICE_ready_o <= 1'b0;
end


always@(posedge clk_i)
begin
    if(rst_i)
    begin
        data_ready <= 0;
        data_feeder_counter <= 32'hFFFFFFFF; // different from df_counter, so ready flag will be zero
        dsa_trigger <= 0;
        dsa_vec_base <= 0;
        dsa_vec_top <= 32'hFFFFFFFF;
    end
    else if(df_en && S_DEVICE_rw_i)
    begin
        if(df_ready_sel) 
            data_ready <= S_DEVICE_data_i;
        else if(df_count_sel) 
            data_feeder_counter <= S_DEVICE_data_i;
        else if(df_trigger_sel) 
            dsa_trigger <= S_DEVICE_data_i;
        else if(df_vec_base_sel)
            dsa_vec_base <= S_DEVICE_data_i;
        else if(df_vec_top_sel)
            dsa_vec_top <= S_DEVICE_data_i;
    end
    else if(df_count_c == (data_feeder_counter+7)) 
    begin 
        data_ready <= 32'h00000001;
        dsa_trigger <= 32'h00000000;
    end
    else 
    begin
        data_ready <= data_ready;
        dsa_vec_base <= dsa_vec_base;
        dsa_vec_top <= dsa_vec_top;
    end
end

always@(posedge clk_i)
begin
    if(rst_i) 
        dsa_result <= 0;
    else if(df_count_c == (data_feeder_counter+7)) 
        dsa_result <= r_data_i;
    else 
        dsa_result <= dsa_result;
end



// =========================================
//  Floating Point IP control
// =========================================
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
        df_count_a <= dsa_vec_base;
    else if(df_count_a < dsa_vec_top)
        df_count_a = df_count_a + 1;
end

always@(posedge clk_i)
begin
    if(rst_i | !(dsa_trigger)) 
        df_count_b <= 0;
    else if(df_count_b < (data_feeder_counter + 8))
        df_count_b = df_count_b + 1;
end

always@(posedge clk_i)
begin
    if(rst_i | !(dsa_trigger)) 
        df_count_c <= 0;
    else if(df_count_c < (data_feeder_counter + 8))
        df_count_c = df_count_c + 1;
end

always@(posedge clk_i)
begin
    if(rst_i)
    begin
        R1 <= 32'h0;
        R2 <= 32'h0;
        R3 <= 32'h0;
    end
    else
    begin
        if(df_count_c == (data_feeder_counter)) 
            R1 <= r_data_i;
        else if(df_count_c == (data_feeder_counter + 1)) 
            R2 <= r_data_i;
        else if(df_count_c == (data_feeder_counter + 2)) 
            R3 <= r_data_i;
    end
end

// computation latency
always@(posedge clk_i)
begin
    if(rst_i)
        compute_lat <= 32'h0;
    else if(dsa_trigger)
        compute_lat <= compute_lat + 1;
end


// =========================================
//  Vector, Weights BRAM 
// =========================================
// Base Address : 0xC4001000
sram_be #(.DATA_WIDTH(32), .N_ENTRIES(1024))
Vector_SRAM_BE(
    .clk_i(clk_i),
    .en_i(S_DEVICE_strobe_i & bram_sel[0]),
    .we_i(S_DEVICE_rw_i),
    .be_i(S_DEVICE_byte_enable_i),
    .addr_i(bram_addr_a),
    .data_i(S_DEVICE_data_i),
    .data_o(vector_buffer_o)
);

// Base Address : 0xC4002000
sram_be #(.DATA_WIDTH(32), .N_ENTRIES(1024))
Weight_SRAM_BE(
    .clk_i(clk_i),
    .en_i(S_DEVICE_strobe_i & bram_sel[1]),
    .we_i(S_DEVICE_rw_i),
    .be_i(S_DEVICE_byte_enable_i),
    .addr_i(bram_addr_b[0]),
    .data_i(S_DEVICE_data_i),
    .data_o(weight_buffer_o[0])
);

// Base Address : 0xC4003000
sram_be #(.DATA_WIDTH(32), .N_ENTRIES(1024))
Weight_SRAM_BE2(
    .clk_i(clk_i),
    .en_i(S_DEVICE_strobe_i & bram_sel[2]),
    .we_i(S_DEVICE_rw_i),
    .be_i(S_DEVICE_byte_enable_i),
    .addr_i(bram_addr_b[1]),
    .data_i(S_DEVICE_data_i),
    .data_o(weight_buffer_o[1])
);

endmodule
