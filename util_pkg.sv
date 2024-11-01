`timescale 1ns/1ps

package util_pkg;

    import mcm_decimal_pkg::*;

    typedef longint unsigned uint64_t;

    //----------------------------
    // STANDARD VERBOSITY LEVELS
    //----------------------------

    localparam                  VERBOSITY_OPERATION     = 1;
    localparam                  VERBOSITY_INFO          = 2;
    localparam                  VERBOSITY_DEBUG         = 4;

    //----------------------------
    // TEST DATA CLASS
    //----------------------------

    /*
    * pseudo constrained randomization class for test data - all the freely 
    * available tools don't support actual constrained randomization. This class 
    * still provides a way of getting a randomized dynamic 2-dimensional regular 
    * arary with the individual vectors of the array all randomized.
    * Zero-initialization is possible as well, for data type consistency between 
    * different test data objects (for example when one is for writing and the 
    * other is read-back, to be compared afterwards)
    * Additionally, some conversion methods are provided between packed and 
    * unpacked (because dynamic arrays by definition are unpacked, but most 
    * hardware/dut interaction likes packed vectors).
    */
    class cls_test_data;

        logic data [][];

        function new (input int num_words, input int bitwidth,
            input bit randomize_data=0);
            data = new[num_words];
            foreach (data[i]) data[i] = new[bitwidth];
            initialize(randomize_data);
        endfunction // new

        function void initialize(input bit randomize_data=0);
            if (randomize_data) begin
                this.randomize_data();
            end else begin
                this.set_zero();
            end
        endfunction // new

        function void randomize_data();
            foreach (data[i,j]) data[i][j] = $random;
        endfunction // randomize_data

        function void set_zero();
            foreach (data[i,j]) data[i][j] = 0;
        endfunction // set_zero

        /*
        * number of data words
        */
        function int get_len();
            return $size(data);
        endfunction // get_len

        /*
        * bitwidth of data words
        */
        function int get_size();
            return $size(data[0]);
        endfunction // get_size

        /*
        * test for equality with another cls_test_data object
        */
        function bit equals (cls_test_data data_compare);
            return data == data_compare.data;
        endfunction // equals

        // TODO: we need a way of doing these functions dynamically, regardless 
        // of bit widths. And then they should just throw an error if some 
        // bitwidths are impossible to match to each other.

        /*
        * return the data item at index as packed 8-bit vector
        */
        function bit [7:0] pack8_item (int index);
            bit [7:0] data_packed;
            data_packed = {>>8{data[index]}};
            data_packed = {<<{data_packed}};
            return data_packed;
        endfunction

        /*
        * get the data as a dynamic array of 8-bit packed vectors
        */
        function void pack8 (ref bit [7:0] data_packed []);
            data_packed = new[this.get_len()];
            for (int i=0; i<this.get_len(); i++) begin
                data_packed[i] = this.pack8_item(i);
            end
        endfunction

        /*
        * write the data item data to the test data field at index
        */
        function void unpack8_item (bit [7:0] data, int index);
            {<<{this.data[index]}} = data;
        endfunction

        /*
        * return the data item at index as packed 32-bit vector
        */
        function bit [31:0] pack32_item (int index);
            bit [31:0] data_packed;
            data_packed = {>>32{data[index]}};
            data_packed = {<<{data_packed}};
            return data_packed;
        endfunction

        /*
        * get the data as a dynamic array of 32-bit packed vectors
        */
        function void pack32 (ref bit [31:0] data_packed []);
            data_packed = new[this.get_len()];
            for (int i=0; i<this.get_len(); i++) begin
                data_packed[i] = this.pack32_item(i);
            end
        endfunction

        /*
        * write the data item data to the test data field at index
        */
        function void unpack32_item (bit [31:0] data, int index);
            {<<{this.data[index]}} = data;
        endfunction

        /*
        * return the data item at index as packed 64-bit vector
        */
        function bit [63:0] pack64_item (int index);
            bit [63:0] data_packed;
            data_packed = {>>64{data[index]}};
            data_packed = {<<{data_packed}};
            return data_packed;
        endfunction

        /*
        * get the data as a dynamic array of 32-bit packed vectors
        */
        function void pack64 (ref bit [63:0] data_packed []);
            data_packed = new[this.get_len()];
            for (int i=0; i<this.get_len(); i++) begin
                data_packed[i] = this.pack64_item(i);
            end
        endfunction

        /*
        * write the data item data to the test data field at index
        */
        function void unpack64_item (bit [63:0] data, int index);
            {<<{this.data[index]}} = data;
        endfunction

        /*
        * print the generated data in a 64-bit casted hex format
        * (obviously will fail in some way if the data words are wider than 64 
        * bits, but it does the job for quick debugging)
        */
        function void print64();
            bit [63:0] data_packed [];
            this.pack64(data_packed);
            foreach (data_packed[i]) begin
                $display("data item %0d: %h", i, data_packed[i]);
            end
//             for (int i=0; i<$size(data); i++) begin
//                 data_packed = {>>64{data[i]}};
//                 data_packed = {<<{data_packed}};
//                 $display("data item %0d: %h", i, data_packed);
//             end
        endfunction // print64

        /*
        * print the generated data in a 256-bit casted hex format
        * (obviously will fail in some way if the data words are wider than 64 
        * bits, but it does the job for quick debugging)
        */
        function void print256();
            bit [255:0] data_packed;
            for (int i=0; i<$size(data); i++) begin
                data_packed = {>>256{data[i]}};
                data_packed = {<<{data_packed}};
                $display("data item %0d: %h", i, data_packed);
            end
        endfunction // print256

    endclass // cls_test_data

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
        // !!! WARNING !!! function has proven to be unreliable with certain 
        // simulators because some simulators have a weird understanding of what 
        // a "reference" would be (and when it needs to be updated). When using, 
        // check with your simulator of choice that the function behaves as it 
        // should.
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
    // MATH FUNCTIONS
    //----------------------------

    /*
     * helper class (you could say dummy) for creating parameterized functions 
     * to process integer-type numbers of arbitrary width.
     * The point is that most of the systemverilog integer system is built for 
     * 32-bit, 64-bit at best. If you need anything wider, nothing applies that 
     * is not standard logic datatype arithmetic. The problem that led to 
     * creating this class were the random functions, because these are all only 
     * 32-bit, not even 64-bit. So for wider full-precision random numbers, you 
     * need to concatenate. And you can't directly parameterize standalone 
     * functions, so the solution was a wrapper class.
     */
    class cls_wide_int #(
        parameter           BIT_WIDTH = 64
    );
        localparam          MAX_WIDE_INT = {BIT_WIDTH{1'b1}};
        localparam          NUM_32INT = $floor(BIT_WIDTH/32);
        localparam          BITS_REMAINDER_32INT = BIT_WIDTH - 32*NUM_32INT;

        typedef bit[BIT_WIDTH-1:0] wide_int_t;

        function new();
        endfunction

        /*
         * return a random number of BIT_WIDTH
         */
        static function wide_int_t get_random(wide_int_t min=0, wide_int_t max=MAX_WIDE_INT);
            automatic wide_int_t result = '0;
            automatic int i=0;
            // how to concatenate: In general, go from MSB to LSB in 32-bit 
            // blocks (set the size of the most significant block to just 
            // dynamically fill up the remaining bitwidth). Record as soon as 
            // you encounter a bit set in `max` in the current slice 
            // (`max_larger`).  If the first `max` bit is in the current slice, 
            // then the `max` slice is the random range limit for the current 
            // result slice. If a `max` bit was set in a higher slice, it 
            // doesn't matter what the current slice does, freely randomize.
            automatic bit max_larger = 1'b0;
            result[BIT_WIDTH-1 -: BITS_REMAINDER_32INT] =
                            $urandom_range(0, max[BIT_WIDTH-1 -: BITS_REMAINDER_32INT]);
            if (! max[BIT_WIDTH-1 -: BITS_REMAINDER_32INT] == '0) begin
                max_larger = 1'b1;
            end
            for (i=(NUM_32INT*32); i>0; i-=32) begin
                if (max_larger) begin
                    result[i-1 -: 32] = $urandom;
                end else begin
                    // (note that max[i-1 -: 32] can still be '0 at this point, 
                    // but that behaves correctly regardless of `max_larger`)
                    result[i-1 -: 32] = $urandom_range(0, max[i-1 -: 32]);
                    if (! max[i-1 -: 32] == 32'b0) begin
                        max_larger = 1'b1;
                    end
                end
            end

            return result;
        endfunction
    endclass // cls_wide_random

    /*
    * hold equality information about two real numbers: `equals` holds the 
    * result of `real_equals`, delta the actuall difference between the two 
    * numbers. Handy in case equality test goes wrong, to see how far off you 
    * were.
    */
    typedef struct {
        bit                 equals;
        real                delta;
    } real_bool_t;

    /*
     * test equality of two real numbers - by testing if they are less than 
     * epsilon apart
     */
    function automatic real_bool_t real_equals(real operand_1, real operand_2, real epsilon=1e-5);
        // (didn't find a systemverilog abs function - if there is, please let 
        // me know)
        real_bool_t result;
        if (operand_1>operand_2) begin
            result.equals = operand_1-operand_2 < epsilon ? 1'b1 : 1'b0;
            result.delta = operand_1-operand_2;
        end else begin
            result.equals = operand_2-operand_1 < epsilon ? 1'b1 : 1'b0;
            result.delta = operand_2-operand_1;
        end
        return result;
    endfunction

    // verificationacademy.com/forums/t/is-there-a-function-which-returns-the-largest-value-in-systemverilog-like-max-in-c/31001
    let max(num_1, num_2) = (num_1 > num_2) ? num_1 : num_2;

    /*
    * generate a randomized constrained real number
    * :min/max: minimum and maximum, as expected
    * :user_min_exponent: minimum NON-BIASED (you could say "human-readable") 
    * exponent. Defaults to miminum possible value (aka no restriction), 
    * including the all 0's biased exponent (allowing zero and denormalized 
    * numbers).
    */
    function automatic real real_random(real min, real max,
                            int user_min_exponent=-fun_float_exponent_bias(FLOAT_STD_IEEE_754_64));
        // (I'm not sure if I really need all of - or even any - of these 
        // `automatic` classifiers. But it works, so the hell I'm not going to 
        // touch it)
        automatic bit [63:0] max_bits = $realtobits(max);
        automatic uint64_t max_exponent = uint64_t'(max_bits[62:52]);
        automatic uint64_t max_mantissa = uint64_t'(max_bits[51:0]);
        automatic bit max_sign_bit = max_bits[63];
        automatic bit [63:0] min_bits = $realtobits(min);
        automatic uint64_t min_exponent = uint64_t'(min_bits[62:52]);
        automatic uint64_t min_mantissa = uint64_t'(min_bits[51:0]);
        automatic bit min_sign_bit = min_bits[63];

        // determined later depending on the sign bits
        automatic uint64_t actual_min_exponent;
        automatic uint64_t actual_max_exponent;
        automatic uint64_t actual_min_mantissa;
        automatic uint64_t actual_max_mantissa;

        automatic uint64_t user_min_exponent_biased =
                        user_min_exponent + fun_float_exponent_bias(FLOAT_STD_IEEE_754_64);

        automatic bit sign_bit;
        automatic bit [10:0] exponent;
        automatic bit [51:0] mantissa;

        // TLDR: 1. choose a random sign bit that meets min and max. 2.  
        // Depending on the sign bit, determine the valid exponent range -> 
        // choose a random exponent from that range. 3. Choose a random 
        // mantissa. In case the selected exponent hits any of the constraints, 
        // make sure to restrict the mantissa such that the constraints 
        // eventually are met.

        // STEP 1: SIGN BIT
        // if the max is negative, result has to be negative, and vice versa if 
        // the min is positive. if min<0<max the sign bit is random
        if (max_sign_bit) begin
            sign_bit = 1'b1;
        end else if (~min_sign_bit) begin
            sign_bit = 1'b0;
        end else begin
            sign_bit = $urandom;
        end

        // STEP 2: EXPONENT
        // need to differentiate which of min_exponent and max_exponent applies, 
        // based on the sign bits. (Example: If we have (min, max) = (-2,3) but 
        // sign_bit=1'b0, any other min_* constraint is irrelevant)
        case (sign_bit)
            1'b0: begin
                if (min_sign_bit) begin
                    // result>=0, (max>0), min<0
                    actual_min_exponent = '0;
                    actual_min_mantissa = '0;
                    actual_max_exponent = max_exponent;
                    actual_max_mantissa = max_mantissa;
                end else begin
                    // result>=0, (max>0), min>=0
                    actual_min_exponent = min_exponent;
                    actual_min_mantissa = min_mantissa;
                    actual_max_exponent = max_exponent;
                    actual_max_mantissa = max_mantissa;
                end
            end
            1'b1: begin
                if (~max_sign_bit) begin
                    // result<0, (min<0), max>=0
                    actual_min_exponent = '0;
                    actual_min_mantissa = '0;
                    actual_max_exponent = min_exponent;
                    actual_max_mantissa = min_mantissa;
                end else begin
                    // result<0, (min<0), max<0
                    actual_min_exponent = max_exponent;
                    actual_min_mantissa = max_mantissa;
                    actual_max_exponent = min_exponent;
                    actual_max_mantissa = min_mantissa;
                end
            end
        endcase
        if (actual_min_exponent < user_min_exponent_biased) begin
            actual_min_exponent = user_min_exponent_biased;
            actual_min_mantissa = '0;
        end
        exponent = $urandom_range(actual_min_exponent, actual_max_exponent);

        // STEP 3: MANTISSA
        // if the exponent is not the actual maximum or minimum exponent, the 
        // mantissa is fully random because then the result can't exceed the 
        // boundaries.  If the exponent is max_exponent, mantissa has to be 
        // lower-equal the maximum mantissa. Likewise if the exponent is 
        // min_exponent, the mantissa has to be larger-equal min_mantissa.
        if (exponent == actual_max_exponent) begin
            mantissa = cls_wide_int#(52)::get_random(0, actual_max_mantissa);
        end else if (exponent == actual_min_exponent) begin
            mantissa = cls_wide_int#(52)::get_random(actual_min_mantissa);
        end else begin
            mantissa = cls_wide_int#(52)::get_random();
        end

        return $bitstoreal({sign_bit, exponent, mantissa});
    endfunction

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
        $display(" success rate: %.2f%%", real'(success)/(success+failed)*100);
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
