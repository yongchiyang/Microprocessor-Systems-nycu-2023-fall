`timescale 1ns / 1ps

`define dsa_copy_start 32'h800039b4
`define dsa_copy_end 32'h800039dc

`define neuron_eval_start 32'h800014c4
`define neuron_eval_end 32'h800016a4 // ret

`define ping_pong_start 32'h800016b8
`define ping_pong_end 32'h80001914 // ret

`define ping_pong_v_start 32'h80001b40
`define ping_pong_v_end 32'h80001da8 // ret

`define one_buffer_start 32'h80001930
`define one_buffer_end 32'h80001b24 // ret

module profiler
#( parameter XLEN = 32 )
(
    input                       clk_i,
    input                       rst_i,

    input                       stall_data_i,
    input                       stall_from_exe_i,
    input                       load_store_i,

    input                       d_strobe_i,
    input                       d_cache_hit_i,

    input [XLEN-1 : 0]          exe_pc2mem_i,
    input [XLEN-1 : 0]          wbk_pc_i
);

(* mark_debug="true" *) reg [XLEN*2-1 : 0]      neuron_mem_lat;
(* mark_debug="true" *) reg [XLEN-1 : 0]        neuron_compute_lat;
(* mark_debug="true" *) reg [XLEN-1 : 0]        dsa_copy_lat;
(* mark_debug="true" *) reg [XLEN-1 : 0]        neuron_cnt, ping_cnt, one_buff_cnt, ping_v_cnt;
(* mark_debug="true" *) reg neuron_en, ping_en, one_buff_en, ping_v_en;
(* mark_debug="true" *) reg dsa_cpy_en;
(* mark_debug="true" *) reg [7:0] count;
(* mark_debug="true" *) reg [9:0] dsa_cnt;


always@(posedge clk_i) 
begin
    if(rst_i)
        count <= 0;
    else if(exe_pc2mem_i == `neuron_eval_end)
        count <= count + 1;
    else if(exe_pc2mem_i == `ping_pong_end)
        count <= count + 1;
    else if(exe_pc2mem_i == `one_buffer_end)
        count <= count + 1;
    else
        count <= count;
end

always@(posedge clk_i)
begin
    if(rst_i)
        neuron_en <= 1'b0;
    else if((exe_pc2mem_i == `neuron_eval_start) && (count < 100))
        neuron_en <= 1'b1;
    else if(exe_pc2mem_i == `neuron_eval_end)
        neuron_en <= 1'b0;
    else
        neuron_en <= neuron_en;
end

always@(posedge clk_i)
begin
    if(rst_i)
        ping_en <= 1'b0;
    else if(exe_pc2mem_i == `ping_pong_start && (count < 100))
        ping_en <= 1'b1;
    else if(exe_pc2mem_i == `ping_pong_end)
        ping_en <= 1'b0;
    else
        ping_en <= ping_en;
end

always@(posedge clk_i)
begin
    if(rst_i)
        one_buff_en <= 1'b0;
    else if(exe_pc2mem_i == `one_buffer_start && (count < 100))
        one_buff_en <= 1'b1;
    else if(exe_pc2mem_i == `one_buffer_end)
        one_buff_en <= 1'b0;
    else
        one_buff_en <= one_buff_en;
end

always@(posedge clk_i)
begin
    if(rst_i)
        ping_v_en <= 1'b0;
    else if(exe_pc2mem_i == `ping_pong_v_start && (count < 100)) 
        ping_v_en <= 1'b1;
    else if(exe_pc2mem_i == `ping_pong_v_end)
        ping_v_en <= 1'b0;
    else
        ping_v_en <= ping_v_en;
end

always@(posedge clk_i)
begin
    if(rst_i)
        dsa_cnt <= 0;
    else if(wbk_pc_i == `dsa_copy_end)
        dsa_cnt <= dsa_cnt + 1;
    else
        dsa_cnt <= dsa_cnt;
end

always@(posedge clk_i)
begin
    if(rst_i)
        dsa_cpy_en <= 1'b0;
    else if(exe_pc2mem_i == `dsa_copy_start)
        dsa_cpy_en <= 1'b1;
    else if(wbk_pc_i == `dsa_copy_end)
        dsa_cpy_en <= 1'b0;
    else
        dsa_cpy_en <= dsa_cpy_en;
end

always@(posedge clk_i)
begin
    if(rst_i)
    begin
        neuron_mem_lat <= 32'h0;
        neuron_compute_lat <= 32'h0;
        dsa_copy_lat <= 32'h0;
    end
    else if(neuron_en)
    begin
        if(stall_data_i || load_store_i)
            neuron_mem_lat <= neuron_mem_lat + 1;
        else if(stall_from_exe_i)
            neuron_compute_lat <= neuron_compute_lat + 1;
    end 
    else if(dsa_cpy_en)
        dsa_copy_lat <= dsa_copy_lat + 1;
    else
    begin
        neuron_mem_lat <= neuron_mem_lat;
        neuron_compute_lat <= neuron_compute_lat;
        dsa_copy_lat <= dsa_copy_lat;
    end
end

always@(posedge clk_i)
begin
    if(rst_i)
    begin
        neuron_cnt <= 32'h0;
        ping_cnt <= 32'h0;
        one_buff_cnt <= 32'h0;
        ping_v_cnt <= 32'h0;
    end
    else if(d_strobe_i & ~(d_cache_hit_i))
    begin
        if(neuron_en)
            neuron_cnt <= neuron_cnt + 1;
        if(ping_en)
            ping_cnt <= ping_cnt + 1;
        if(one_buff_en)
            one_buff_cnt <= one_buff_cnt + 1;
        if(ping_v_en)
            ping_v_cnt <= ping_v_cnt + 1;
    end
    else
    begin
        neuron_cnt <= neuron_cnt;
        ping_cnt <= ping_cnt;
        one_buff_cnt <= one_buff_cnt;
        ping_v_cnt <= ping_v_cnt;
    end
end

endmodule