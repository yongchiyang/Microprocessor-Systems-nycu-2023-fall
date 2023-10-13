// start and end address for 5 hotspots
/*
`define CORE_LIST_REVERSE_S 32'h00001d48
`define CORE_LIST_REVERSE_E 32'h00001d68
`define CORE_LIST_FIND_S 32'h00001cf0
`define CORE_LIST_FIND_E 32'h00001d44
`define CORE_STATE_TRANSITION_S 32'h000029dc
`define CORE_STATE_TRANSITION_E 32'h00002cd4
`define MATRIX_MUL_MATRIX_BITEXTRACT_S 32'h00002638
`define MATRIX_MUL_MATRIX_BITEXTRACT_E 32'h000026f4
`define CRCU8_S 32'h000019b0
`define CRCU8_E 32'h000019f0
*/
`define CORE_LIST_REVERSE_S 32'h00001d80
`define CORE_LIST_REVERSE_E 32'h00001da0
`define CORE_LIST_FIND_S 32'h00001d28
`define CORE_LIST_FIND_E 32'h00001d7c
`define CORE_STATE_TRANSITION_S 32'h00002a14
`define CORE_STATE_TRANSITION_E 32'h00002d0c
`define MATRIX_MUL_MATRIX_BITEXTRACT_S 32'h00002670
`define MATRIX_MUL_MATRIX_BITEXTRACT_E 32'h0000272c
`define CRCU8_S 32'h000019e8
`define CRCU8_E 32'h00001a28
`define MAIN_ENT 32'h00001088
`define MAIN_RET 32'h00001770
`define CORE_LIST_MERGESORT_S 32'h00001d6c
`define CORE_LIST_MERGESORT_E 32'h00001eb8

module profiler #( parameter XLEN = 32 )
(
    //  Processor clock and reset signals.
    input                 clk_i,
    input                 rst_i,


    input      [XLEN-1:0] pc_i,

    input                 ls_wb,
    input                 ls_total,
    input                 data_hazard,
    input                 fetch_stall,
    input                 exe_stall,
    
    
    output reg [XLEN+3:0] core_list_reverse_o,
    output reg [XLEN+3:0] core_list_find_o,
    output reg [XLEN+3:0] core_state_transition_o,
    output reg [XLEN+3:0] matrix_mul_matrix_bitextract_o,
    output reg [XLEN+3:0] crcu8_o,
    
    output reg [XLEN+3:0] ls_core_list_reverse,
    output reg [XLEN+3:0] ls_core_list_find,
    output reg [XLEN+3:0] ls_core_state_transition,
    output reg [XLEN+3:0] ls_matrix_mul_matrix_bitextract,
    output reg [XLEN+3:0] ls_crcu8,

    output reg [XLEN+3:0] ls_total_core_list_reverse,
    output reg [XLEN+3:0] ls_total_core_list_find,
    output reg [XLEN+3:0] ls_total_core_state_transition,
    output reg [XLEN+3:0] ls_total_matrix_mul_matrix_bitextract,
    output reg [XLEN+3:0] ls_total_crcu8,

    output reg [XLEN+3:0] hazard_core_list_reverse,
    output reg [XLEN+3:0] hazard_core_list_find,
    output reg [XLEN+3:0] hazard_core_state_transition,
    output reg [XLEN+3:0] hazard_matrix_mul_matrix_bitextract,
    output reg [XLEN+3:0] hazard_crcu8,  
    
    output reg [XLEN+3:0] data_fetch_core_list_reverse,
    output reg [XLEN+3:0] data_fetch_core_list_find,
    output reg [XLEN+3:0] data_fetch_core_state_transition,
    output reg [XLEN+3:0] data_fetch_matrix_mul_matrix_bitextract,
    output reg [XLEN+3:0] data_fetch_crcu8,

    output reg [XLEN+3:0] exe_core_list_reverse,
    output reg [XLEN+3:0] exe_core_list_find,
    output reg [XLEN+3:0] exe_core_state_transition,
    output reg [XLEN+3:0] exe_matrix_mul_matrix_bitextract,
    output reg [XLEN+3:0] exe_crcu8

);

(* mark_debug="true" *) reg [XLEN*2-1 :0 ] main_count;
reg main_start;

always@(posedge clk_i)
begin
    if(rst_i) main_start <= 0;
    else if (pc_i == `MAIN_ENT) main_start <= 1;
    else main_start <= main_start;
end

always@(posedge clk_i)
begin
    if(rst_i) main_count = 0;
    else if(main_start) main_count = main_count + 1;
    else main_count = main_count;
end


always@(posedge clk_i)
begin
    if(rst_i)
    begin
        
        core_list_reverse_o <= 0;
        core_list_find_o <= 0;
        core_state_transition_o <= 0;
        matrix_mul_matrix_bitextract_o <= 0;
        crcu8_o <= 0;

        ls_core_list_reverse <= 0;
        ls_core_list_find <= 0;
        ls_core_state_transition <= 0;
        ls_matrix_mul_matrix_bitextract <= 0;
        ls_crcu8 <= 0;

        ls_total_core_list_reverse <= 0;
        ls_total_core_list_find <= 0;
        ls_total_core_state_transition <= 0;
        ls_total_matrix_mul_matrix_bitextract <= 0;
        ls_total_crcu8 <= 0;

        hazard_core_list_reverse <= 0;
        hazard_core_list_find <= 0;
        hazard_core_state_transition <= 0;
        hazard_matrix_mul_matrix_bitextract <= 0;
        hazard_crcu8 <= 0;

        data_fetch_core_list_reverse <= 0;
        data_fetch_core_list_find <= 0;
        data_fetch_core_state_transition <= 0;
        data_fetch_matrix_mul_matrix_bitextract <= 0;
        data_fetch_crcu8 <= 0;

        exe_core_list_reverse <= 0;
        exe_core_list_find <= 0;
        exe_core_state_transition <= 0;
        exe_matrix_mul_matrix_bitextract <= 0;
        exe_crcu8 <= 0;

    end
    else
    begin
        if(pc_i >= `CORE_LIST_REVERSE_S && pc_i <= `CORE_LIST_REVERSE_E)
        begin
            core_list_reverse_o <= core_list_reverse_o + 1;
            if(ls_wb) ls_core_list_reverse = ls_core_list_reverse + 1;
            if(ls_total) ls_total_core_list_reverse = ls_total_core_list_reverse + 1;
            if(data_hazard) hazard_core_list_reverse = hazard_core_list_reverse + 1;
            if(fetch_stall) data_fetch_core_list_reverse = data_fetch_core_list_reverse + 1;
            if(exe_stall) exe_core_list_reverse <= exe_core_list_reverse + 1;
        end
        else if(pc_i >= `CORE_LIST_FIND_S && pc_i <= `CORE_LIST_FIND_E)
        begin
            core_list_find_o <= core_list_find_o + 1;
            if(ls_wb) ls_core_list_find = ls_core_list_find + 1;
            if(ls_total) ls_total_core_list_find = ls_total_core_list_find + 1;
            if(data_hazard) hazard_core_list_find = hazard_core_list_find + 1;
            if(fetch_stall) data_fetch_core_list_find = data_fetch_core_list_find + 1;
            if(exe_stall) exe_core_list_find <= exe_core_list_find + 1;
        end
        else if(pc_i >= `CORE_STATE_TRANSITION_S && pc_i <= `CORE_STATE_TRANSITION_E)
        begin
            core_state_transition_o <= core_state_transition_o + 1;
            if(ls_wb) ls_core_state_transition = ls_core_state_transition + 1;
            if(ls_total) ls_total_core_state_transition = ls_total_core_state_transition + 1;
            if(data_hazard) hazard_core_state_transition = hazard_core_state_transition + 1;
            if(fetch_stall) data_fetch_core_state_transition = data_fetch_core_state_transition + 1;
            if(exe_stall) exe_core_state_transition <= exe_core_state_transition + 1;
        end
        else if(pc_i >= `MATRIX_MUL_MATRIX_BITEXTRACT_S && pc_i <= `MATRIX_MUL_MATRIX_BITEXTRACT_E)
        begin
            matrix_mul_matrix_bitextract_o <= matrix_mul_matrix_bitextract_o + 1;
            if(ls_wb) ls_matrix_mul_matrix_bitextract = ls_matrix_mul_matrix_bitextract + 1;
            if(ls_total) ls_total_matrix_mul_matrix_bitextract = ls_total_matrix_mul_matrix_bitextract + 1;
            if(data_hazard) hazard_matrix_mul_matrix_bitextract = hazard_matrix_mul_matrix_bitextract + 1;
            if(fetch_stall) data_fetch_matrix_mul_matrix_bitextract = data_fetch_matrix_mul_matrix_bitextract + 1;
            if(exe_stall) exe_matrix_mul_matrix_bitextract <= exe_matrix_mul_matrix_bitextract + 1;
        end
        else if(pc_i >= `CRCU8_S && pc_i <= `CRCU8_E)
        begin
            crcu8_o <= crcu8_o + 1;
            if(ls_wb) ls_crcu8 = ls_crcu8 + 1;
            if(ls_total) ls_total_crcu8 = ls_total_crcu8 + 1;
            if(data_hazard) hazard_crcu8 = hazard_crcu8 + 1;
            if(fetch_stall) data_fetch_crcu8 = data_fetch_crcu8 + 1;
            if(exe_stall) exe_crcu8 <= exe_crcu8 + 1;
        end
    end
end

endmodule