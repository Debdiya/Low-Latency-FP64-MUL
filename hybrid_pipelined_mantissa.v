`timescale 1ns/1ps

module fp64_mantissa_mul_hybrid_pipe3 (
    input  wire         clk,
    input  wire         rst,
    input  wire         in_valid,
    input  wire [52:0]  mant_a,
    input  wire [52:0]  mant_b,
    output reg  [105:0] mant_prod,
    output reg          mant_valid,
    output wire         valid_s1_out,
    output wire         valid_s2_out,
    output wire         valid_s3_out
);

    // =========================================================
    // VALID PIPELINE  (4 stages: vs1→vs2→vs3→mant_valid)
    // =========================================================
    reg valid_s1, valid_s2, valid_s3;

    assign valid_s1_out = valid_s1;
    assign valid_s2_out = valid_s2;
    assign valid_s3_out = valid_s3;

    always @(posedge clk) begin
        if (rst) begin
            valid_s1    <= 1'b0;
            valid_s2    <= 1'b0;
            valid_s3    <= 1'b0;
            mant_valid  <= 1'b0;
        end else begin
            valid_s1   <= in_valid;
            valid_s2   <= valid_s1;
            valid_s3   <= valid_s2;
            mant_valid <= valid_s3;
        end
    end

    // =========================================================
    // STAGE 1  -  Karatsuba partial products (combinational)
    //             Input: mant_a, mant_b  (live inputs this cycle)
    //             Output registered by: in_valid
    // =========================================================
    wire [26:0] a_hi = mant_a[52:26];
    wire [25:0] a_lo = mant_a[25:0];
    wire [26:0] b_hi = mant_b[52:26];
    wire [25:0] b_lo = mant_b[25:0];

    // Upper 27×27 partial product (54 bits)
    wire [53:0] p_hi = a_hi * b_hi;

    // Lower 26×26 via four Vedic 13×13 tiles (52 bits)
    wire [12:0] a0 = a_lo[12:0];
    wire [12:0] a1 = a_lo[25:13];
    wire [12:0] b0 = b_lo[12:0];
    wire [12:0] b1 = b_lo[25:13];

    wire [25:0] p00, p01, p10, p11;
    vedic_13x13 u00 (.a(a0), .b(b0), .y(p00));
    vedic_13x13 u01 (.a(a0), .b(b1), .y(p01));
    vedic_13x13 u10 (.a(a1), .b(b0), .y(p10));
    vedic_13x13 u11 (.a(a1), .b(b1), .y(p11));

    wire [51:0] p_lo =
          ({26'b0, p00})
        + ({13'b0, p01, 13'b0})
        + ({13'b0, p10, 13'b0})
        + ({p11,   26'b0});

    // Karatsuba cross term:
    //   cross = (a_hi+a_lo)*(b_hi+b_lo) - p_hi - p_lo   (56 bits)
    wire [27:0] sum_a = {1'b0, a_hi} + {2'b00, a_lo};   // 28 bits
    wire [27:0] sum_b = {1'b0, b_hi} + {2'b00, b_lo};   // 28 bits
    wire [55:0] p_mid = sum_a * sum_b;                    // 56 bits

    wire [55:0] cross = p_mid
                      - {2'b00, p_hi}    // zero-extend 54b→56b
                      - {4'b00, p_lo};   // zero-extend 52b→56b

    // -------- Stage-1 registers (gate: in_valid) --------
    //   Capture the Karatsuba partials for the CURRENT input.
    //   Gating on in_valid (not valid_s1!) ensures we capture THIS
    //   cycle's data before in_valid deasserts or changes.
    reg [53:0] p_hi_r;
    reg [51:0] p_lo_r;
    reg [55:0] cross_r;

    always @(posedge clk) begin
        if (rst) begin
            p_hi_r  <= 0;
            p_lo_r  <= 0;
            cross_r <= 0;
        end else if (in_valid) begin      // ← gate: in_valid
            p_hi_r  <= p_hi;
            p_lo_r  <= p_lo;
            cross_r <= cross;
        end
    end

    // =========================================================
    // STAGE 2  -  Pipeline buffer for Stage-1 outputs
    //             Needed so CSA can run one full cycle later while
    //             Stage-1 regs are safely overwritten by the next input.
    //             Gate: valid_s1
    // =========================================================
    reg [53:0] p_hi_r2;
    reg [51:0] p_lo_r2;
    reg [55:0] cross_r2;

    always @(posedge clk) begin
        if (rst) begin
            p_hi_r2  <= 0;
            p_lo_r2  <= 0;
            cross_r2 <= 0;
        end else if (valid_s1) begin      // ← gate: valid_s1
            p_hi_r2  <= p_hi_r;
            p_lo_r2  <= p_lo_r;
            cross_r2 <= cross_r;
        end
    end

    // =========================================================
    // STAGE 3  -  CSA final summation (combinational from Stage-2 regs)
    //
    //   Full 106-bit product =  p_hi * 2^52  +  cross * 2^26  +  p_lo
    //
    //   FIX: use all 56 bits of cross_r2 (original code used only [53:0],
    //        silently discarding the top 2 bits and corrupting results).
    // =========================================================
    wire [105:0] term_hi  = {p_hi_r2,  52'b0};          // 54b shifted left 52
    wire [105:0] term_mid = {24'b0, cross_r2, 26'b0};   // 56b shifted left 26  ← FIX
    wire [105:0] term_lo  = {54'b0, p_lo_r2};            // 52b zero-padded

    wire [105:0] csa_sum   = term_hi ^ term_mid ^ term_lo;
    wire [105:0] csa_carry = (term_hi & term_mid)
                           | (term_mid & term_lo)
                           | (term_hi & term_lo);

    wire [105:0] mant_s3   = csa_sum + (csa_carry << 1);

    // -------- Stage-3 register (gate: valid_s2) --------
    reg [105:0] mant_s3_r;

    always @(posedge clk) begin
        if (rst)            mant_s3_r <= 0;
        else if (valid_s2)  mant_s3_r <= mant_s3;  // ← gate: valid_s2
    end

    // =========================================================
    // STAGE 4  -  Output register (gate: valid_s3)
    // =========================================================
    always @(posedge clk) begin
        if (rst)            mant_prod <= 0;
        else if (valid_s3)  mant_prod <= mant_s3_r;  // ← gate: valid_s3
    end

endmodule