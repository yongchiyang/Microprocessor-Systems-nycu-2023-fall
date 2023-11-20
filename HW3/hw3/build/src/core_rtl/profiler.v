`timescale 1ns / 1ps

`include "aquila_config.vh"

module profiler #(parameter XLEN = 32)
(  
    input                       clk_i,
    input                       rst_i,

    input [XLEN-1 : 0]          pc_addr_i,
    input                       strobe_i, // (S == Ananlysis && ~p_is_amo_i)
    input                       cache_hit_i, // cache_hit
    input                       rw_i,       // rw
    input                       victim_dirty_i, // c_dirty_o[victim_sel]
    input                       flush_i, //busy_flushing_o
    input                       ready_i, //p_ready_o

    output reg [XLEN-1 : 0]   write_hit,
    output reg [XLEN-1 : 0]   write_miss,
    output reg [XLEN-1 : 0]   write_dirty,
    output reg [XLEN-1 : 0]   read_hit,
    output reg [XLEN-1 : 0]   read_miss,
    output reg [XLEN-1 : 0]   read_dirty,
    output reg [XLEN-1 : 0]   flush,

    output reg [XLEN+7 : 0]   write_miss_latency,
    output reg [XLEN+7 : 0]   write_miss_dirty_latency,
    output reg [XLEN+7 : 0]   read_miss_latency,
    output reg [XLEN+7 : 0]   read_miss_dirty_latency,
    output reg [XLEN+7 : 0]   flush_latency,
    output reg [XLEN+7 : 0]   hit_latency,
    output reg [XLEN+7 : 0]   hit_latency_r,
    output reg [XLEN+7 : 0]   hit_latency_w
);

reg S, S_nxt;
reg en;
reg hit_r, rw_r, dirty_r;
reg main_start;

always@(posedge clk_i)
begin
    if(rst_i) main_start <= 1'b0;
    else if(pc_addr_i == 32'h80000088) main_start <= 1'b1;
    else main_start <= main_start;
end

always@(posedge clk_i)
begin
    if(rst_i) en <= 1'b0;
    else if(strobe_i) en <= 1'b1;
    else if(S == 1'b1) en <= 1'b0; // count p_ready_o
    //else if(ready_i) en <= 1'b0; // this will induce error
end

always@(posedge clk_i)
begin
    S <= S_nxt;
end

always@(*)
begin
    case(S)
        1'b0:
            if(ready_i) S_nxt = 1'b1;
            else S_nxt = 1'b0;
        1'b1: 
            S_nxt = 1'b0;
        default: 
            S_nxt = 1'b0;
    endcase
end

always@(posedge clk_i)
begin
    if(strobe_i)
    begin
        hit_r <= cache_hit_i;
        rw_r <= rw_i;
        dirty_r <= victim_dirty_i;
        //flush_r <= flush_i;
    end
end

// count number of each hit/miss/diry/rw
always@(posedge clk_i)
begin
    if(rst_i)
    begin
        write_hit <= 0;
        write_miss <= 0;
        write_dirty <= 0;
        read_hit <= 0;
        read_miss <= 0;
        read_dirty <= 0;
        flush <= 0;
    end
    else if(main_start)
    begin
        if(strobe_i && flush_i) flush = flush + 1;
        else if(strobe_i & cache_hit_i & rw_i) write_hit <= write_hit + 1;
        else if(strobe_i & cache_hit_i) read_hit <= read_hit + 1;
        else if(strobe_i & (~cache_hit_i) & rw_i) 
        begin
            if(victim_dirty_i) write_dirty <= write_dirty + 1;
            write_miss <= write_miss + 1;
        end
        else if(strobe_i & (~cache_hit_i))
        begin
            if(victim_dirty_i) read_dirty <= read_dirty + 1;
            read_miss <= read_miss + 1;
        end
        else
        begin
            write_hit <= write_hit;
            write_miss <= write_miss;
            write_dirty <= write_dirty;
            read_hit <= read_hit;
            read_miss <= read_miss;
            read_dirty <= read_dirty;
        end
    end
end

// accumulate latency cycles
always@(posedge clk_i)
begin
    if(rst_i)
    begin
        write_miss_latency <= 0;
        write_miss_dirty_latency <= 0;
        read_miss_latency <= 0;
        read_miss_dirty_latency <= 0;
        flush_latency <= 0;
        hit_latency <= 0;

        hit_latency_r <= 0;
        hit_latency_w <= 0;
    end
    else if(flush_i) flush_latency = flush_latency + 1;
    else if(main_start)
    begin
        if(strobe_i) // when S == Ananlysis
        begin
            if(cache_hit_i && ~flush_i)
            begin
                hit_latency = hit_latency + 1;
                if(rw_i) hit_latency_w = hit_latency_w + 1;
                else hit_latency_r = hit_latency_r + 1;
            end
            else
            begin
                if(rw_i && victim_dirty_i) write_miss_dirty_latency = write_miss_dirty_latency + 1;
                if(rw_i && ~victim_dirty_i) write_miss_latency = write_miss_latency + 1;
                if(~rw_i && victim_dirty_i) read_miss_dirty_latency = read_miss_dirty_latency + 1;
                if(~rw_i && ~victim_dirty_i) read_miss_latency = read_miss_latency + 1;
            end
        end
        else if (en)
        begin
            begin
                if(hit_r)
                begin
                    hit_latency = hit_latency + 1;
                    if(rw_r) hit_latency_w = hit_latency_w + 1;
                    else hit_latency_r = hit_latency_r + 1;
                end
                else 
                begin
                    if(rw_r && dirty_r) write_miss_dirty_latency = write_miss_dirty_latency + 1;
                    if(rw_r && ~dirty_r) write_miss_latency = write_miss_latency + 1;
                    if(~rw_r && dirty_r) read_miss_dirty_latency = read_miss_dirty_latency + 1;
                    if(~rw_r && ~dirty_r) read_miss_latency = read_miss_latency + 1;
                end
                
            end
        end
    end
end

endmodule