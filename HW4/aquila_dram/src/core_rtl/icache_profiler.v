`timescale 1ns / 1ps

`include "freertos_code.vh"

module icache_profiler #(parameter XLEN = 32)
(  
    input                       clk_i,
    input                       rst_i,

    input [XLEN-1 : 0]          pc_addr_i, // pcu_pc
    input                       i_strobe_i, // S == Next 

    input                       i_cache_hit_i, // cache_hit
    input                       i_ready_i //p_ready_o

);

reg task_start;
reg cntxt_sw_en, mutex_give_en, mutex_take_en;

(* mark_debug="true" *) reg [XLEN-1 : 0]     hit_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]     miss_cnt;

(* mark_debug="true" *) reg [XLEN-1 : 0]     ISR_hit_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]     ISR_miss_cnt;

(* mark_debug="true" *) reg [XLEN-1 : 0]     mutex_take_hit_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]     mutex_take_miss_cnt;

(* mark_debug="true" *) reg [XLEN-1 : 0]     mutex_give_hit_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]     mutex_give_miss_cnt;

(* mark_debug="true" *) reg [XLEN-1 : 0]     enter_cri_hit_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]     enter_cri_miss_cnt;

(* mark_debug="true" *) reg [XLEN-1 : 0]     exit_cri_hit_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]     exit_cri_miss_cnt;

always@(posedge clk_i)
begin
    if(rst_i) task_start <= 1'b0;
    else if(pc_addr_i == `TASK1_HANDLER_ENT) task_start <= 1'b1;
    else if(pc_addr_i == `TASK1_DELETE) task_start <= 1'b0;
    else task_start <= task_start;
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
        if(i_strobe_i & i_cache_hit_i) 
        begin
            hit_cnt <= hit_cnt + 1;
            if(cntxt_sw_en || pc_addr_i ==`IRQ_HANDLE_ENT || pc_addr_i == `PROCESSED_SRC_END) ISR_hit_cnt = ISR_hit_cnt + 1;
            if(mutex_give_en || pc_addr_i == `SEMAPHORE_GIVE_ENT || pc_addr_i == `SEMAPHORE_GIVE_RET) mutex_give_hit_cnt = mutex_give_hit_cnt + 1;
            if(mutex_take_en || pc_addr_i == `SEMAPHORE_TAKE_ENT || pc_addr_i == `SEMAPHORE_TAKE_RET) mutex_take_hit_cnt = mutex_take_hit_cnt + 1;
            if(pc_addr_i >= `ENTER_CRITICAL_ENT && pc_addr_i <= `ENTER_CRITICAL_RET) enter_cri_hit_cnt = enter_cri_hit_cnt + 1;
            if(pc_addr_i >= `EXIT_CRITICAL_ENT && pc_addr_i <= `EXIT_CRITICAL_RET) exit_cri_hit_cnt = exit_cri_hit_cnt + 1;
        end
        else if(i_strobe_i & (~i_cache_hit_i)) 
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


endmodule