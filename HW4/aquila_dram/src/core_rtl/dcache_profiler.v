`timescale 1ns / 1ps
`include "freertos_code.vh"

module dcache_profiler #(parameter XLEN = 32)
(  
    input                       clk_i,
    input                       rst_i,

    input [XLEN-1 : 0]          pc_addr_i, // exe_pc
    input                       d_strobe_i, // (S == Ananlysis && ~p_is_amo_i)
    input                       d_cache_hit_i, // cache_hit
    input                       d_ready_i //p_ready_o

);

reg S, S_nxt;
reg en;
reg hit_r, rw_r, dirty_r;
reg task_start;
reg cntxt_sw_en, mutex_give_en, mutex_take_en;

(* mark_debug="true" *) reg [XLEN-1 : 0]     hit_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]     miss_cnt;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   miss_latency;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   hit_latency;

(* mark_debug="true" *) reg [XLEN-1 : 0]     ISR_hit_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]     ISR_miss_cnt;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   ISR_miss_latency;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   ISR_hit_latency;

(* mark_debug="true" *) reg [XLEN-1 : 0]     mutex_take_hit_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]     mutex_take_miss_cnt;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   mutex_take_miss_latency;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   mutex_take_hit_latency;

(* mark_debug="true" *) reg [XLEN-1 : 0]     mutex_give_hit_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]     mutex_give_miss_cnt;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   mutex_give_miss_latency;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   mutex_give_hit_latency;

(* mark_debug="true" *) reg [XLEN-1 : 0]     enter_cri_hit_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]     enter_cri_miss_cnt;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   enter_cri_miss_latency;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   enter_cri_hit_latency;

(* mark_debug="true" *) reg [XLEN-1 : 0]     exit_cri_hit_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]     exit_cri_miss_cnt;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   exit_cri_miss_latency;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   exit_cri_hit_latency;

always@(posedge clk_i)
begin
    if(rst_i) task_start <= 1'b0;
    else if(pc_addr_i == `TASK1_HANDLER_ENT) task_start <= 1'b1;
    else if(pc_addr_i == `TASK1_DELETE) task_start <= 1'b0;
    else task_start <= task_start;
end

always@(posedge clk_i)
begin
    if(rst_i) en <= 1'b0;
    else if(d_strobe_i) en <= 1'b1;
    else if(S == 1'b1) en <= 1'b0; // count p_ready_o
    //else if(d_ready_i) en <= 1'b0; // this will induce error
end

always@(posedge clk_i)
begin
    S <= S_nxt;
end

always@(*)
begin
    case(S)
        1'b0:
            if(d_ready_i) S_nxt = 1'b1;
            else S_nxt = 1'b0;
        1'b1: 
            S_nxt = 1'b0;
        default: 
            S_nxt = 1'b0;
    endcase
end

always@(posedge clk_i)
begin
    if(d_strobe_i)
    begin
        hit_r <= d_cache_hit_i;
    end
end



// count number of each hit/miss/diry/rw
always@(posedge clk_i)
begin
    if(rst_i)
    begin
        hit_cnt <= 0;
        ISR_hit_cnt <= 0;
        mutex_give_hit_cnt <= 0;
        mutex_take_hit_cnt <= 0;
        enter_cri_hit_cnt <= 0;
        exit_cri_hit_cnt <= 0;

        miss_cnt <= 0;
        ISR_miss_cnt <= 0;
        mutex_give_miss_cnt <= 0;
        mutex_take_miss_cnt <= 0;
        enter_cri_miss_cnt <= 0;
        exit_cri_miss_cnt <= 0;
    end
    else if(task_start)
    begin
        if(d_strobe_i & d_cache_hit_i) 
        begin
            hit_cnt <= hit_cnt + 1;
            if(cntxt_sw_en || pc_addr_i ==`IRQ_HANDLE_ENT || pc_addr_i == `PROCESSED_SRC_END) ISR_hit_cnt = ISR_hit_cnt + 1;
            if(mutex_give_en || pc_addr_i == `SEMAPHORE_GIVE_ENT || pc_addr_i == `SEMAPHORE_GIVE_RET) mutex_give_hit_cnt = mutex_give_hit_cnt + 1;
            if(mutex_take_en || pc_addr_i == `SEMAPHORE_TAKE_ENT || pc_addr_i == `SEMAPHORE_TAKE_RET) mutex_take_hit_cnt = mutex_take_hit_cnt + 1;
            if(pc_addr_i >= `ENTER_CRITICAL_ENT && pc_addr_i <= `ENTER_CRITICAL_RET) enter_cri_hit_cnt = enter_cri_hit_cnt + 1;
            if(pc_addr_i >= `EXIT_CRITICAL_ENT && pc_addr_i <= `EXIT_CRITICAL_RET) exit_cri_hit_cnt = exit_cri_hit_cnt + 1;
        end
        else if(d_strobe_i & (~d_cache_hit_i)) 
        begin
            miss_cnt <= miss_cnt + 1;
            if(cntxt_sw_en || pc_addr_i ==`IRQ_HANDLE_ENT || pc_addr_i == `PROCESSED_SRC_END) ISR_miss_cnt = ISR_miss_cnt + 1;
            if(mutex_give_en || pc_addr_i == `SEMAPHORE_GIVE_ENT || pc_addr_i == `SEMAPHORE_GIVE_RET) mutex_give_miss_cnt = mutex_give_miss_cnt + 1;
            if(mutex_take_en || pc_addr_i == `SEMAPHORE_TAKE_ENT || pc_addr_i == `SEMAPHORE_TAKE_RET) mutex_take_miss_cnt = mutex_take_miss_cnt + 1;
            if(pc_addr_i >= `ENTER_CRITICAL_ENT && pc_addr_i <= `ENTER_CRITICAL_RET) enter_cri_miss_cnt = enter_cri_miss_cnt + 1;
            if(pc_addr_i >= `EXIT_CRITICAL_ENT && pc_addr_i <= `EXIT_CRITICAL_RET) exit_cri_miss_cnt = exit_cri_miss_cnt + 1;
        end
    end
end



always@(posedge clk_i)
begin
    if(rst_i)
    begin
        cntxt_sw_en <= 1'b0;
        mutex_give_en <= 1'b0;
        mutex_take_en <= 1'b0;
    end
    else
    begin
        if(pc_addr_i == `IRQ_HANDLE_ENT) cntxt_sw_en <= 1'b1;
        else if(pc_addr_i == (`PROCESSED_SRC_END)) cntxt_sw_en <= 1'b0;
        else cntxt_sw_en <= cntxt_sw_en;

        if(pc_addr_i == `SEMAPHORE_GIVE_ENT) mutex_give_en <= 1'b1;
        else if(pc_addr_i == `SEMAPHORE_GIVE_RET) mutex_give_en <= 1'b0;
        else mutex_give_en <= mutex_give_en;

        if(pc_addr_i == `SEMAPHORE_TAKE_ENT) mutex_take_en <= 1'b1;
        else if(pc_addr_i == `SEMAPHORE_TAKE_RET) mutex_take_en <= 1'b0;
        else mutex_take_en <= mutex_take_en;
    end
end


// accumulate latency cycles
always@(posedge clk_i)
begin
    if(rst_i)
    begin
        hit_latency <= 0;
        ISR_hit_latency <= 0;
        mutex_give_hit_latency <= 0;
        mutex_take_hit_latency <= 0;
        enter_cri_hit_latency <= 0;
        exit_cri_hit_latency <= 0;

        miss_latency <= 0;
        ISR_miss_latency <= 0;
        mutex_give_miss_latency <= 0;
        mutex_take_miss_latency <= 0;
        enter_cri_miss_latency <= 0;
        exit_cri_miss_latency <= 0;
    end
    else if(task_start)
    begin
        if (en)
        begin
            begin
                if(hit_r) 
                begin
                    hit_latency = hit_latency + 1;
                    if(cntxt_sw_en) ISR_hit_latency = ISR_hit_latency + 1;
                    if(mutex_give_en) mutex_give_hit_latency = mutex_give_hit_latency + 1;
                    if(mutex_take_en) mutex_take_hit_latency = mutex_take_hit_latency + 1;
                    if(pc_addr_i >= `ENTER_CRITICAL_ENT && pc_addr_i <= `ENTER_CRITICAL_RET) enter_cri_hit_latency = enter_cri_hit_latency + 1;
                    if(pc_addr_i >= `EXIT_CRITICAL_ENT && pc_addr_i <= `EXIT_CRITICAL_RET) exit_cri_hit_latency = exit_cri_hit_latency + 1;
                end
                else
                begin
                     miss_latency <= miss_latency + 1;
                     if(cntxt_sw_en) ISR_miss_latency = ISR_miss_latency + 1;
                     if(mutex_give_en) mutex_give_miss_latency = mutex_give_miss_latency + 1;
                     if(mutex_take_en) mutex_take_miss_latency = mutex_take_miss_latency + 1;
                     if(pc_addr_i >= `ENTER_CRITICAL_ENT && pc_addr_i <= `ENTER_CRITICAL_RET) enter_cri_miss_latency = enter_cri_miss_latency + 1;
                     if(pc_addr_i >= `EXIT_CRITICAL_ENT && pc_addr_i <= `EXIT_CRITICAL_RET) exit_cri_miss_latency = exit_cri_miss_latency + 1;
                end
            end
        end
    end
end

endmodule