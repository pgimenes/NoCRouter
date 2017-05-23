`timescale 1ns / 1ps

import noc_params::*;

module tb_vc_allocator #(
    parameter VC_TOTAL = 10,
    parameter PORT_NUM = 5,
    parameter VC_NUM = 2
);
    
    /*VC ALLOCATOR*/
    logic rst, clk;

    logic [VC_TOTAL-1:0] idle_downstream_vc_i;
    
    logic [VC_TOTAL-1:0] vc_to_allocate_i;
    
    port_t [VC_TOTAL-1:0] out_port_i;
    
    logic [VC_SIZE-1:0] vc_new_o [VC_TOTAL-1:0];

    logic [VC_SIZE-1:0] vc_new_generated [VC_TOTAL-1:0];
    
    logic [VC_TOTAL-1:0] vc_valid_o, vc_valid_generated;
    
    port_t [PORT_NUM-1:0] ports = {LOCAL, NORTH, SOUTH, WEST, EAST};

    /*SEPARABLE INPUT FIRST ALLOCATOR*/

    localparam [31:0] AGENTS_PTR_SIZE = $clog2(VC_TOTAL);
    
    logic [VC_TOTAL-1:0][VC_TOTAL-1:0] requests_cmd_i;

    logic [VC_TOTAL-1:0][AGENTS_PTR_SIZE-1:0] curr_highest_priority_in, next_highest_priority_in;
    
    logic [VC_TOTAL-1:0][AGENTS_PTR_SIZE-1:0] curr_highest_priority_out, next_highest_priority_out;

    logic [VC_TOTAL-1:0][VC_TOTAL-1:0] grants_in_trasp, grants_out;
    
    logic [VC_TOTAL-1:0][VC_TOTAL-1:0] grants_in, grants_out_trasp;

    /*RESOURCES AVAILABILITY VECTOR*/
    
    logic [VC_TOTAL-1:0] available_vc_curr, available_vc_prox;

    /*DUT INSTANTIATION*/
    
    vc_allocator #(
        .VC_TOTAL(VC_TOTAL),
        .PORT_NUM(PORT_NUM),
        .VC_NUM(VC_NUM)
    )
    vc_allocator (
        .rst(rst),
        .clk(clk),
        .idle_downstream_vc_i(idle_downstream_vc_i),
        .vc_to_allocate_i(vc_to_allocate_i),
        .out_port_i(out_port_i),
        .vc_new_o(vc_new_o),
        .vc_valid_o(vc_valid_o)
    );
    /*
    The testbench performs four different test:
    1) Simulation of the basic tasks that the allocator has to perform, all the requests are cumulative
    2) Simulation of a corner case: all the upstream vcs request the same port.
    3) Simulation of a corner case: after all the request have been granted the downstream vc is not in idle, so all the resources have been 
     exhausted, after that all the downstream vcs return in idle and the resources recover.
    4) Simulation of a corner case: a reset is performed during the execution of the module and then normal tasks are executed.
    */
    initial 
    begin
        dump_output();
        initialize();
        clear_reset();
        test_cumulative_requests();
        test_same_port_requests();
        test_exhaust_vc_and_return_availability();
        test_reset();
        $display("[ALLOCATOR] PASSED");
        #15 $finish;
    end 

    always #5 clk = ~clk ;

    task dump_output();
            $dumpfile("out.vcd");
            $dumpvars(0, tb_vc_allocator);
    endtask

    task clear_reset();
        begin
            @(posedge clk);
            rst <= 0;
        end
    endtask

    task initialize();
        clk <= 0;
        rst  = 1;
        available_vc_curr  = {VC_TOTAL{1'b1}};
        curr_highest_priority_in = {VC_TOTAL{1'b0}};
        curr_highest_priority_out = {VC_TOTAL{1'b0}};
        vc_to_allocate_i = {VC_TOTAL{1'b0}};
    endtask
    
    task reset();
        rst  = 1;
        available_vc_curr  = {VC_TOTAL{1'b1}};
        curr_highest_priority_in = {VC_TOTAL{1'b0}};
        curr_highest_priority_out = {VC_TOTAL{1'b0}};
        vc_to_allocate_i = {VC_TOTAL{1'b0}};
    endtask
    /*First test the vc allocator is called to execute a number of basic tasks*/
    task test_cumulative_requests();
        repeat(10) @(posedge clk)
        begin
            idle_downstream_vc_i = {VC_TOTAL{$random}};
            for(int i = 0; i < VC_TOTAL; i++)
                out_port_i[i] = ports[$urandom_range(4,0)];
            vc_to_allocate_i = {VC_TOTAL{$random}};
            test_check();
        end
    endtask
    /*
    Second test: all the upstream vcs request the same port
    */
    task test_same_port_requests();
        for(int j = 0; j < PORT_NUM; j++)
        begin
            @(posedge clk)
            idle_downstream_vc_i = {VC_TOTAL{1'b1}};
            for (int i = 0; i < VC_TOTAL; i++)
                out_port_i[i] = ports[j];
            vc_to_allocate_i = {VC_TOTAL{1'b1}};
            test_check();
        end
    endtask
    /*
    Third test all the downstream vc are not in idle (5clk) and then they return in idle again
    */
    task test_exhaust_vc_and_return_availability();
        for(int j = 0; j < PORT_NUM; j++)
        begin
            @(posedge clk)
            idle_downstream_vc_i = {VC_TOTAL{1'b0}};
            for (int i = 0; i < VC_TOTAL; i++)
                out_port_i[i] = ports[$urandom_range(4,0)];
            vc_to_allocate_i = {VC_TOTAL{1'b1}};
            test_check();
        end
        
        for(int j = 0; j < PORT_NUM; j++)
        begin
            @(posedge clk)
            idle_downstream_vc_i = {VC_TOTAL{1'b1}};
            for (int i = 0; i < VC_TOTAL; i++)
                out_port_i[i] = ports[$urandom_range(4,0)];
            vc_to_allocate_i = {VC_TOTAL{1'b1}};
            test_check();
        end
    endtask
    /*
    Fourth and last test a reset is performed before the operations
    */
    task test_reset();
        @(posedge clk, posedge rst)
            reset();   
        clear_reset();
        repeat(10) @(posedge clk)
        begin
            idle_downstream_vc_i = {VC_TOTAL{$random}};
            for(int i = 0; i < VC_TOTAL; i++)
                out_port_i[i] = ports[$urandom_range(4,0)];
            vc_to_allocate_i = {VC_TOTAL{$random}};
            test_check();
        end
    endtask
    /*
    The test simulates an internal separable input first allocator and the operations of the vc allocator
    then checks that everything corresponds to the output
    */
    task test_check();
        available_vc_prox = available_vc_curr;
        vc_valid_generated = {VC_TOTAL{1'b0}};
        requests_cmd_i = {VC_TOTAL*VC_TOTAL{1'b0}};
        for(int up_vc = 0; up_vc < VC_TOTAL; up_vc = up_vc + 1)
            vc_new_generated[up_vc] = {VC_SIZE{1'bx}};
        for(int up_vc = 0; up_vc < VC_TOTAL; up_vc = up_vc + 1)
        begin
            for(int down_vc = 0; down_vc < VC_TOTAL; down_vc = down_vc + 1)
            begin
                if(vc_to_allocate_i[up_vc] & available_vc_curr[down_vc] & (down_vc / VC_NUM) == out_port_i[up_vc])
                begin
                    requests_cmd_i[up_vc][down_vc] = 1'b1;
                end
            end
        end

        for(int k = 0; k < VC_TOTAL; k = k + 1)
        begin
            grants_in[k]  =  {VC_TOTAL{1'b0}};
            next_highest_priority_in[k] = curr_highest_priority_in[k];
            for(int i = 0; i < VC_TOTAL; i = i + 1)
            begin
                if(requests_cmd_i[k][(curr_highest_priority_in[k] + i) % VC_TOTAL])
                begin
                    grants_in[k][(curr_highest_priority_in[k] + i) % VC_TOTAL] = 1'b1; 
                    next_highest_priority_in[k] = (curr_highest_priority_in[k] + i + 1) % VC_TOTAL;
                    break;
                end
            end
            curr_highest_priority_in[k] = next_highest_priority_in[k]; 
        end

        for(int i = 0; i < VC_TOTAL ; i++)
        begin
            for(int j = 0; j < VC_TOTAL; j++)
            begin
                grants_in_trasp[j][i] = grants_in[i][j]; 
            end
        end

        for(int k = 0; k < VC_TOTAL; k = k + 1)
        begin
        grants_out[k]  =  {VC_TOTAL{1'b0}};
        next_highest_priority_out[k] = curr_highest_priority_out[k];
        for(int i = 0; i < VC_TOTAL; i = i + 1)
            begin
                if(grants_in_trasp[k][(curr_highest_priority_out[k] + i) % VC_TOTAL])
                begin
                    grants_out[k][(curr_highest_priority_out[k] + i) % VC_TOTAL] = 1'b1;
                    next_highest_priority_out[k] = (curr_highest_priority_out[k] + i + 1) % VC_TOTAL;
                    break;
                end
            end
            curr_highest_priority_out[k] = next_highest_priority_out[k];
        end

        for(int i = 0; i < VC_TOTAL ; i++)
        begin
            for(int j = 0; j < VC_TOTAL; j++)
            begin
                grants_out_trasp[j][i] = grants_out[i][j];
            end
        end

        for(int up_vc = 0; up_vc < VC_TOTAL; up_vc = up_vc + 1)
        begin
            for(int down_vc = 0; down_vc < VC_TOTAL; down_vc = down_vc + 1)
            begin
                if(grants_out_trasp[up_vc][down_vc])
                begin
                    vc_new_generated[up_vc] = (VC_SIZE)'(down_vc % VC_NUM);
                    vc_valid_generated[up_vc] = 1'b1;
                    available_vc_prox[down_vc] = 1'b0;
                end
            end
        end

        for(int down_vc = 0; down_vc < VC_TOTAL; down_vc = down_vc + 1)
        begin
            if(~available_vc_curr[down_vc] & idle_downstream_vc_i[down_vc])
            begin
                available_vc_prox[down_vc] = 1'b1;
            end
        end
        available_vc_curr = available_vc_prox;
        check();
    endtask
    
    task check();
        @(negedge clk)
        for(int j = 0; j < VC_TOTAL; j++)
        begin
            if(vc_new_generated[j]!==vc_new_o[j])
            begin
            $display("[ALLOCATOR] FAILED time: %d", $time);
            #5 $finish;
            end       
        end

        for(int j = 0; j < VC_TOTAL; j++)
        begin
            if(vc_valid_generated[j]!==vc_valid_o[j])
            begin
            $display("[ALLOCATOR] FAILED time: %d", $time);
            #5 $finish;
            end
        end
    endtask

endmodule
