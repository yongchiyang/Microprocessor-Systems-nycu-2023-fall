`timescale 1ns / 1ps
`include "freertos_code.vh"

// include software timer 
// test if software timer is being used
//`define SFT_TIMER_ENT 32'h80006b20
//`define SFT_TIMER_END 32'h80006e18

// exclude software timer
/*
`define TASK1_HANDLER_ENT 32'h800010e8
`define TASK1_DELETE 32'h80001310
`define IRQ_HANDLE_ENT 32'h80006900
`define IRQ_HANDLE_END 32'h8000698c
`define PROCESSED_SRC_END 32'h80006ae8
*/


// overall latency should from IRQ_HANDLE_ENT to PROCESSED_SRC_END(mret)
module profiler
#( parameter XLEN = 32 )
(
    input                       clk_i,
    input                       rst_i,
    input                       stall_i,

    input [XLEN-1 : 0]          wbk_pc_i
);

(* mark_debug="true" *) reg cntxt_sw_en;
(* mark_debug="true" *) reg mutex_give_en;
(* mark_debug="true" *) reg mutex_take_en;
(* mark_debug="true" *) reg enter_critical_en;
(* mark_debug="true" *) reg exit_critical_en;
(* mark_debug="true" *) reg task_start;


(* mark_debug="true" *) reg [XLEN*2-1 : 0]  total_cycles;
(* mark_debug="true" *) reg [XLEN-1 : 0]    enter_critical_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]    exit_critical_cnt;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]  enter_critical;
// since after enter_critical, ret, wbk_pc2csr will still process exit_critical
// count the total value when ret
(* mark_debug="true" *) reg [XLEN*2-1 : 0]  exit_critical;

(* mark_debug="true" *) reg [XLEN-1 : 0]     cntx_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]     mutex_take_cnt;
(* mark_debug="true" *) reg [XLEN-1 : 0]     mutex_give_cnt;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   cntx_sw;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   mutex_take;
(* mark_debug="true" *) reg [XLEN*2-1 : 0]   mutex_give;
(* mark_debug="true" *) reg [20:0] tmp;

always@(posedge clk_i)
begin
    if(rst_i) task_start <= 1'b0;
    else if(wbk_pc_i == `TASK1_HANDLER_ENT) task_start <= 1'b1;
    else if(wbk_pc_i == `TASK1_DELETE) task_start <= 1'b0;
    else task_start <= task_start;
end

always@(posedge clk_i)
begin
    if(rst_i)
        tmp <= 0;
    else if(task_start)
    begin
        if(wbk_pc_i == `EXIT_CRITICAL_ENT) tmp <= 0;
        else if(exit_critical_en) tmp <= tmp + 1;
        else tmp <= 0;
    end
end



always@(posedge clk_i)
begin
    if(rst_i)
    begin
        cntxt_sw_en <= 1'b0;
        mutex_give_en <= 1'b0;
        mutex_take_en <= 1'b0;
        enter_critical_en <= 1'b0;
        exit_critical_en <= 1'b0;
    end
    else
    begin
        if(wbk_pc_i == `IRQ_HANDLE_ENT) cntxt_sw_en <= 1'b1;
        else if(wbk_pc_i == (`PROCESSED_SRC_END + 4)) cntxt_sw_en <= 1'b0;
        else cntxt_sw_en <= cntxt_sw_en;

        if(wbk_pc_i == `SEMAPHORE_GIVE_ENT) mutex_give_en <= 1'b1;
        else if(wbk_pc_i == `SEMAPHORE_GIVE_RET + 4) mutex_give_en <= 1'b0;
        else mutex_give_en <= mutex_give_en;

        if(wbk_pc_i == `SEMAPHORE_TAKE_ENT) mutex_take_en <= 1'b1;
        else if(wbk_pc_i == `SEMAPHORE_TAKE_RET + 4) mutex_take_en <= 1'b0;
        else mutex_take_en <= mutex_take_en;

        if(wbk_pc_i == `ENTER_CRITICAL_ENT) enter_critical_en <= 1'b1;
        else if(wbk_pc_i == `ENTER_CRITICAL_RET) enter_critical_en <= 1'b0;
        else enter_critical_en <= enter_critical_en;

        if(wbk_pc_i == `EXIT_CRITICAL_ENT) exit_critical_en <= 1'b1;
        else if(wbk_pc_i == `EXIT_CRITICAL_RET) exit_critical_en <= 1'b0;
        else exit_critical_en <= exit_critical_en;
    end
end


always@(posedge clk_i)
begin
    if(rst_i)
    begin
        cntx_sw <= 0;
        cntx_cnt <= 0;
        mutex_take <= 0;
        mutex_take_cnt <= 0;
        mutex_give <= 0;
        mutex_give_cnt <= 0;

        total_cycles <= 0;

        enter_critical_cnt <= 0;
        exit_critical_cnt <= 0;
        enter_critical <= 0;
        exit_critical <= 0;
        
    end
    else if(task_start)
    begin
        if(wbk_pc_i == `IRQ_HANDLE_ENT  && !stall_i) cntx_cnt <= cntx_cnt + 1;
        if(wbk_pc_i == `SEMAPHORE_TAKE_ENT && !stall_i) mutex_take_cnt <= mutex_take_cnt + 1;
        if(wbk_pc_i == `SEMAPHORE_GIVE_ENT && !stall_i) mutex_give_cnt <= mutex_give_cnt + 1;
        if(wbk_pc_i == `ENTER_CRITICAL_ENT && !stall_i) enter_critical_cnt <= enter_critical_cnt + 1;
        if(wbk_pc_i == `EXIT_CRITICAL_RET && !stall_i) exit_critical_cnt <= exit_critical_cnt + 1;


        if(cntxt_sw_en) cntx_sw <= cntx_sw + 1;
        if(mutex_take_en) mutex_take <= mutex_take + 1;
        if(mutex_give_en) mutex_give <= mutex_give + 1;
        if(enter_critical_en) enter_critical <= enter_critical + 1;
        if(wbk_pc_i == `EXIT_CRITICAL_RET) exit_critical <= exit_critical + tmp + 1;
        
        total_cycles = total_cycles + 1;
    end
end
endmodule