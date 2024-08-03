`timescale 1ns/1ps

package util_pkg;

    //----------------------------
    // VERBOSITY LEVELS
    //----------------------------

    localparam                  VERBOSITY_OPERATION     = 1;
    localparam                  VERBOSITY_INFO          = 2;
    localparam                  VERBOSITY_DEBUG         = 4;

    //----------------------------
    // WAIT TASKS
    //----------------------------

    /*
    * blocking wait for cycles number of ev_clk events.
    */
    task wait_cycles_ev(event ev_clk, int cycles);
        for (int i=0; i<cycles; i++) begin
            @ev_clk;
        end
    endtask

    task automatic wait_cycles_sig(ref logic clk, input int cycles);
        $warning("use carefully, using references has shown to be unreliable");
        if (`VERBOSITY >= VERBOSITY_INFO) begin
            $display("with lower-tier simulators (xsim, modelsim starter) - they seem to treat " ,
            "reference as inputs (thus don't update the values), which makes this " ,
            "task both useless and block the simulation");
        end

        if (`VERBOSITY >= VERBOSITY_DEBUG) begin
            $display("[%0t] starting waiting", $time);
        end

        for (int i=0; i<cycles; i++) begin
            if (`VERBOSITY >= VERBOSITY_DEBUG) begin
                $display("[%0t] still waiting", $time);
            end
            @(posedge clk);
            if (`VERBOSITY >= VERBOSITY_DEBUG) begin
                $display("[%0t] still %0d cycles to wait", $time, i);
            end
        end
        if (`VERBOSITY >= VERBOSITY_DEBUG) begin
            $display("[%0t] finished waiting", $time);
        end
    endtask

    /*
    * waiting for event with simulation time timeout
    */
    task wait_timeout_ev(event ev_sig, int timeout, output logic timed_out);
        timed_out = 0;
        fork begin

            fork
            begin
                #timeout timed_out = 1;
            end
            join_none

            wait(ev_sig.triggered() || timed_out);
            disable fork;

        end join

        if (timed_out) begin
            $warning("[%0t] timeout reached", $time);
        end

    endtask

    task automatic wait_timeout_sig(const ref signal, input int timeout, output logic timed_out);
        timed_out = 0;
        fork begin

            fork
            begin
                #timeout timed_out = 1;
            end
            join_none

            wait(signal || timed_out);
            disable fork;

        end join

        if (timed_out) begin
            $warning("[%0t] timeout reached", $time);
        end

    endtask

    /*
    * waiting for event with clock cycles timeout
    * 
    * assumes that the calling task is waiting for the posedge causing ev_clk, 
    * not for ev_clk itself. Reason: At a posedge, ev_clk is still 'dangling'.  
    * The fork in this task is coded to consume this 'dangling' event before 
    * actually starting to count.
    */
    task wait_timeout_cycles_ev(event ev_sig, event ev_clk, int cycles,
        output logic timed_out);
        timed_out = 0;
        fork begin
            fork
            begin
                @ev_clk;    // see task comment
                if (`VERBOSITY >= 5) begin
                    $display("[%0t] started waiting", $time);
                end
                wait_cycles_ev(ev_clk, cycles);
                timed_out = 1;
            end
            join_none

            wait(ev_sig.triggered() || timed_out);
            disable fork;

        end join

        if (timed_out) begin
            $warning("[%0t] timeout reached", $time);
        end

    endtask

    // TODO: document which of the tasks does what and why (and with which 
    // simulator)
    task automatic wait_timeout_cycles_sig(const ref logic signal, const ref logic clk,
                input int cycles, output logic timed_out);

        int i;
        timed_out = 0;
        for (i=cycles; i>0; i--) begin
            @(posedge clk);
            if (signal) begin
                break;
            end
        end
        if (i == 0) begin
            timed_out = 1;
        end

        if (timed_out) begin
            $warning("[%0t] timeout reached", $time);
        end

    endtask

    //----------------------------
    // PRINT TASKS
    //----------------------------

    function void print_test_start(string test_name, string test_desc="");
        $display("\n********************");
        $display(" RUNNING TEST: %s", test_name);
        if (test_desc != "") begin
            $display("%s", test_desc);
        end
        $display("********************\n");
    endfunction

    function void print_test_result(string test_name, bit result);
        $display("********************");
        if (result) begin
            $display(" TEST %s PASSED ", test_name);
        end else begin
            $display(" XXX TEST %s FAILED XXX", test_name);
        end
        $display("********************\n");
    endfunction

    function void print_tests_stats(int success, int failed);
        $display("******************************************");
        $display(" TEST STATISTICS");
        $display(" passed: %0d - failed: %0d", success, failed);
        $display(" success rate: %.2f%%", success/(success+failed)*100);
        $display("******************************************\n");
    endfunction


    //----------------------------
    // RESET CONTROLLER
    //----------------------------
    
    // used for clean communication between cls_rst_ctrl and testbench
    parameter RST_ACTIVE_HIGH = 1;
    parameter RST_ACTIVE_LOW = 0;

    /*
    * RST_ACTIVE: reset active logic level
    */
    class cls_rst_ctrl #(
        RST_ACTIVE=RST_ACTIVE_LOW,
        CLK_PERIOD=10
        );

        virtual ifc_rst #(CLK_PERIOD) if_rst;

        function new(virtual ifc_rst #(CLK_PERIOD) if_rst);
            this.if_rst = if_rst;
        endfunction

        function void activate();
            if_rst.rst <= this.RST_ACTIVE;
        endfunction

        function void deactivate();
            if_rst.rst <= ~this.RST_ACTIVE;
        endfunction

        /* call once after creating - sets the reset signal to deasserted state
        * and holds it for 10 cycles. Ensures that there is a clean rst_active
        * edge
        */
        task init();
            @(posedge if_rst.clk);

            if (`VERBOSITY >= VERBOSITY_INFO) begin
                $display("[%0t] deactivating reset", $time);
            end
            this.deactivate();
            if (`VERBOSITY >= VERBOSITY_DEBUG) begin
                $display("[%0t] waiting with reset deactivated", $time);
            end
            #(if_rst.CLK_PERIOD * 10);
            if (`VERBOSITY >= VERBOSITY_DEBUG) begin
                $display("[%0t] waiting done", $time);
            end
        endtask

        /* perform a reset of rst_cycles clock cycles
        */
        task trigger(input int rst_cycles);
            @(posedge if_rst.clk);
            this.activate();
            #(if_rst.CLK_PERIOD * rst_cycles)
            @(posedge if_rst.clk);
            this.deactivate();
            if (`VERBOSITY >= VERBOSITY_OPERATION) begin
                $display("[%0t] reset done", $time);
            end
        endtask

    endclass

endpackage
