`timescale 1ns / 1ps


`define MAIN_ENT 32'h00001088

// coremark1
/*
`define CORE_LIST_REVERSE_S 32'h00001d48
`define CORE_LIST_REVERSE_E 32'h00001d68
`define CORE_LIST_FIND_S 32'h00001cf0
`define CORE_LIST_FIND_E 32'h00001d44
`define MATRIX_MUL_MATRIX_S 32'h0000258c
`define MATRIX_MUL_MATRIX_E 32'h00002634
`define CORE_LIST_MERGESORT_S 32'h00001d6c
`define CORE_LIST_MERGESORT_E 32'h00001eb8
`define CRCU8_S 32'h000019b0
`define CRCU8_E 32'h000019f0
`define MAIN_RET 32'h00001770
`define MAIN_END 32'h000018ac
*/
// coremark0

`define CORE_LIST_REVERSE_S 32'h00001d80
`define CORE_LIST_REVERSE_E 32'h00001da0
`define CORE_LIST_FIND_S 32'h00001d28
`define CORE_LIST_FIND_E 32'h00001d7c
`define MATRIX_MUL_MATRIX_S 32'h000025c4
`define MATRIX_MUL_MATRIX_E 32'h0000266c
`define CORE_LIST_MERGESORT_S 32'h00001da4
`define CORE_LIST_MERGESORT_E 32'h00001ef0
`define CRCU8_S 32'h000019e8
`define CRCU8_E 32'h00001a28
`define MAIN_RET 32'h00001794
`define MAIN_END 32'h000018e4



module profiler #( parameter XLEN = 32 )
(
    //  Processor clock and reset signals.
    input                   clk_i,
    input                   rst_i,


    input      [XLEN-1:0]   pc_i,
    input                   is_stall,

    input                   is_branch,
    input                   branch_hit,
    input                   branch_mispredict,
    input                   branch_taken,

    output reg [XLEN*2-1:0] branch_count,
    output reg [XLEN*2-1:0] branch_hit_count,
    output reg [XLEN*2-1:0] branch_mispred_count,
    output reg [XLEN*2-1:0] branch_taken_count

);

(* mark_debug="true" *) reg [XLEN+3 : 0] core_list_reverse;
(* mark_debug="true" *) reg [XLEN+3 : 0] core_list_reverse_hit;
(* mark_debug="true" *) reg [XLEN+3 : 0] core_list_reverse_misp;

(* mark_debug="true" *) reg [XLEN+3 : 0] core_list_find;
(* mark_debug="true" *) reg [XLEN+3 : 0] core_list_find_hit;
(* mark_debug="true" *) reg [XLEN+3 : 0] core_list_find_misp;

(* mark_debug="true" *) reg [XLEN+3 : 0] mmulm;
(* mark_debug="true" *) reg [XLEN+3 : 0] mmulm_hit;
(* mark_debug="true" *) reg [XLEN+3 : 0] mmulm_misp;

(* mark_debug="true" *) reg [XLEN+3 : 0] core_list_mergesort;
(* mark_debug="true" *) reg [XLEN+3 : 0] core_list_mergesort_hit;
(* mark_debug="true" *) reg [XLEN+3 : 0] core_list_mergesort_misp;

(* mark_debug="true" *) reg [XLEN+3 : 0] crcu8;
(* mark_debug="true" *) reg [XLEN+3 : 0] crcu8_hit;
(* mark_debug="true" *) reg [XLEN+3 : 0] crcu8_misp;

(* mark_debug="true" *) reg [XLEN+3 : 0] main;
(* mark_debug="true" *) reg [XLEN+3 : 0] main_hit;
(* mark_debug="true" *) reg [XLEN+3 : 0] main_misp;

reg in_main;
always@(posedge clk_i)
begin
    if(rst_i) in_main <= 0;
    else if(pc_i == `MAIN_ENT) in_main <= 1;
    else if(pc_i == `MAIN_RET) in_main <= 0;
    else in_main <= in_main;
end

always@(posedge clk_i)
begin
    if(rst_i) 
    begin
        branch_count <= 0;
        branch_hit_count <= 0;
        branch_mispred_count <= 0;
        branch_taken_count <= 0;
    end
    else if(in_main && (!is_stall))
    begin
        if(is_branch) 
        begin
            branch_count <= branch_count + 1;
            if(branch_hit) 
            begin
                branch_hit_count <= branch_hit_count + 1;
                if(branch_mispredict) branch_mispred_count <= branch_mispred_count + 1;
            end
            if(branch_taken) branch_taken_count <= branch_taken_count + 1;
        end
    end
end

always@(posedge clk_i)
begin
    if(rst_i)
    begin
        core_list_reverse <= 0;
        core_list_reverse_hit <= 0;
        core_list_reverse_misp <= 0;

        core_list_find <= 0;
        core_list_find_hit <= 0;
        core_list_find_misp <= 0;

        mmulm <= 0;
        mmulm_hit <= 0;
        mmulm_misp <= 0;

        core_list_mergesort <= 0;
        core_list_mergesort_hit <= 0;
        core_list_mergesort_misp <= 0;

        crcu8 <= 0;
        crcu8_hit <= 0;
        crcu8_misp <= 0;

        main <= 0;
        main_hit <= 0;
        main_misp <= 0;
    end
    else if(!is_stall)
    begin
        if(pc_i >= `CORE_LIST_REVERSE_S && pc_i <= `CORE_LIST_REVERSE_E)
        begin
            if(is_branch)
            begin   
                core_list_reverse <= core_list_reverse + 1;
                if(branch_hit)
                begin  
                    core_list_reverse_hit <= core_list_reverse_hit + 1;
                    if(branch_mispredict) core_list_reverse_misp <= core_list_reverse_misp + 1;
                end
            end
        end
        else if(pc_i >= `CORE_LIST_FIND_S && pc_i <= `CORE_LIST_FIND_E)
        begin
            if(is_branch)
            begin
                core_list_find <= core_list_find + 1;
                if(branch_hit)
                begin
                    core_list_find_hit <= core_list_find_hit + 1;
                    if(branch_mispredict) core_list_find_misp <= core_list_find_misp + 1;
                end
            end
        end
        else if(pc_i >= `MATRIX_MUL_MATRIX_S && pc_i <= `MATRIX_MUL_MATRIX_E)
        begin
            if(is_branch)
            begin
                mmulm <= mmulm + 1;
                if(branch_hit) 
                begin
                    mmulm_hit <= mmulm_hit + 1;
                    if(branch_mispredict) mmulm_misp <= mmulm_misp + 1;
                end
            end
        end
        else if(pc_i >= `CORE_LIST_MERGESORT_S && pc_i <= `CORE_LIST_MERGESORT_E)
        begin
            if(is_branch)
            begin
                core_list_mergesort <= core_list_mergesort + 1;
                if(branch_hit)
                begin
                    core_list_mergesort_hit <= core_list_mergesort_hit + 1;
                    if(branch_mispredict) core_list_mergesort_misp <= core_list_mergesort_misp + 1;
                end
            end
        end
        else if(pc_i >= `CRCU8_S && pc_i <= `CRCU8_E)
        begin
            if(is_branch)
            begin
                crcu8 <= crcu8 + 1;
                if(branch_hit)
                begin
                    crcu8_hit <= crcu8_hit + 1;
                    if(branch_mispredict) crcu8_misp = crcu8_misp + 1;
                end
            end
        end
        else if(pc_i >= `MAIN_ENT && pc_i <= `MAIN_END)
        begin
            if(is_branch)
            begin
                main <= main + 1;
                if(branch_hit)
                begin
                    main_hit <= main_hit + 1;
                    if(branch_mispredict) main_misp <= main_misp + 1;
                end
            end
        end
    end
end

endmodule