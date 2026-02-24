`timescale 1ns/1ps

module tb_fp64_mul_pipe3;

    reg clk;
    reg rst;
    reg in_valid;

    reg  [63:0] a;
    reg  [63:0] b;
    wire [63:0] result;
    wire        mant_valid;

    //------------------------------------------
    // Instantiate DUT
    //------------------------------------------
    fp64_mul_pipe3 dut (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .a(a),
        .b(b),
        .result(result),
        .mant_valid(mant_valid)
    );

    //------------------------------------------
    // Clock
    //------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    //------------------------------------------
    // Expected result FIFO
    //------------------------------------------
    reg [63:0] expected [0:15];
    integer wr_ptr = 0;
    integer rd_ptr = 0;

    //------------------------------------------
    // Apply transaction task
    //------------------------------------------
    task apply;
        input [63:0] in_a;
        input [63:0] in_b;
        input [63:0] exp;
        begin
            @(negedge clk);
            in_valid = 1;
            a = in_a;
            b = in_b;

            expected[wr_ptr] = exp;
            wr_ptr = wr_ptr + 1;
        end
    endtask

    //------------------------------------------
    // Self-checker
    //------------------------------------------
    always @(posedge clk) begin
        if (mant_valid) begin
            if (result !== expected[rd_ptr] &&
                result !== expected[rd_ptr] + 1 &&
                result !== expected[rd_ptr] - 1) begin

                $display("❌ FAIL at time %0t", $time);
                $display("Expected = %h", expected[rd_ptr]);
                $display("Got      = %h", result);
                $fatal;
            end
            else begin
                $display("✅ PASS at time %0t : %h", $time, result);
            end

            rd_ptr = rd_ptr + 1;
        end
    end

    //------------------------------------------
    // Test Sequence
    //------------------------------------------
    initial begin
        rst = 1;
        in_valid = 0;
        a = 0;
        b = 0;

        repeat (3) @(posedge clk);
        rst = 0;

        //------------------------------------------
        // Test 1: 1.5 × 1.25 = 1.875
        //------------------------------------------
        apply(
            64'h3FF8000000000000,  // 1.5
            64'h3FF4000000000000,  // 1.25
            64'h3FFE000000000000   // 1.875
        );

        //------------------------------------------
        // Test 2: 2.0 × 2.0 = 4.0
        //------------------------------------------
        apply(
            64'h4000000000000000,
            64'h4000000000000000,
            64'h4010000000000000
        );

        //------------------------------------------
        // Test 3: 3.2 × 5.5 = 17.6
        //------------------------------------------
        apply(
            64'h400999999999999A,  // 3.2
            64'h4016000000000000,  // 5.5
            64'h403199999999999A   // 17.6
        );

        //------------------------------------------
        // Test 4: -2.5 × 4.0 = -10.0
        //------------------------------------------
        apply(
            64'hC004000000000000,  // -2.5
            64'h4010000000000000,  // 4.0
            64'hC024000000000000   // -10.0
        );

        //------------------------------------------
        // Insert bubble
        //------------------------------------------
        @(negedge clk);
        in_valid = 0;
        a = 0;
        b = 0;

        //------------------------------------------
        // Wait for pipeline drain
        //------------------------------------------
        repeat (8) @(posedge clk);

        $display("====================================");
        $display("All tests completed successfully");
        $display("====================================");
        $finish;
    end

endmodule
