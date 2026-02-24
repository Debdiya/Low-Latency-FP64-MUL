`timescale 1ns / 1ps

module fp64_mul_pipe3 (
    input  wire        clk,
    input  wire        rst,
    input  wire        in_valid,  
    input  wire [63:0] a,
    input  wire [63:0] b,
    output reg  [63:0] result,
    output reg         mant_valid
);


// Control pipeline: stages 0-3
reg signed [12:0] exp_pipe [0:3];
reg               sign_pipe[0:3];
integer k;

// Stage 0: unpack (COMBINATIONAL)
wire sign_a = a[63];
wire sign_b = b[63];
wire [10:0] exp_a = a[62:52];
wire [10:0] exp_b = b[62:52];
wire [51:0] frac_a = a[51:0];
wire [51:0] frac_b = b[51:0];

// Calculate sign (XOR)
wire sign_r = sign_a ^ sign_b;

// Build mantissas (add implied 1 for normalized numbers)
wire [52:0] mant_a = (exp_a == 11'd0) ? {1'b0, frac_a} : {1'b1, frac_a};
wire [52:0] mant_b = (exp_b == 11'd0) ? {1'b0, frac_b} : {1'b1, frac_b};

// FIXED: Calculate initial exponent sum with proper 13-bit extension
wire signed [12:0] exp_a_13 = {2'b00, exp_a};
wire signed [12:0] exp_b_13 = {2'b00, exp_b};
wire signed [12:0] exp_sum = exp_a_13 + exp_b_13 - 13'sd1023;

wire [105:0] mant_prod;
wire mant_valid_internal;

wire v1, v2, v3;

fp64_mantissa_mul_hybrid_pipe3 u_mul (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .mant_a(mant_a),
    .mant_b(mant_b),
    .mant_prod(mant_prod),
    .mant_valid(mant_valid_internal),
    .valid_s1_out(v1),
    .valid_s2_out(v2),
    .valid_s3_out(v3)
);

reg need_norm_r;




always @(posedge clk) begin
    if (rst) begin
        for (k = 0; k < 4; k = k + 1) begin
            exp_pipe[k]  <= 0;
            sign_pipe[k] <= 0;
        end
    end else begin
        // Stage 0 load
        if (in_valid) begin
            exp_pipe[0]  <= exp_sum;
            sign_pipe[0] <= sign_r;
        end

        // Shift ONLY when mantissa pipeline advances
        if (v1) begin
            exp_pipe[1] <= exp_pipe[0];
            sign_pipe[1] <= sign_pipe[0];
        end

        if (v2) begin
            exp_pipe[2] <= exp_pipe[1];
            sign_pipe[2] <= sign_pipe[1];
        end

        if (v3) begin
            exp_pipe[3] <= exp_pipe[2];
            sign_pipe[3] <= sign_pipe[2];
        end
    end
end





// Mantissa multiplier (3-stage pipeline)



// Normalization (combinational, operates on stage 3 outputs)


reg signed [12:0] exp_pipe4;
reg               sign_pipe4;

always @(posedge clk) begin
    if (rst) begin
        exp_pipe4  <= 0;
        sign_pipe4 <= 0;
    end else begin
        exp_pipe4  <= exp_pipe[3];
        sign_pipe4 <= sign_pipe[3];
    end
end
reg mant_valid_s4;

always @(posedge clk) begin
    if (rst)
        need_norm_r <= 0;
    else if (mant_valid_internal)
        need_norm_r <= mant_prod[104];
end

always @(posedge clk) begin
    if (rst)
        mant_valid_s4 <= 0;
    else
        mant_valid_s4 <= mant_valid_internal;
end



// Align binary point
wire [53:0] mant_align = mant_prod[105:52];

// Check if ≥ 2
wire need_norm = mant_align[53];

// Normalize mantissa
wire [53:0] mant_norm =
    need_norm ? (mant_align >> 1)
              : mant_align;

// Exponent adjust
wire signed [12:0] exp_norm =
    need_norm ? (exp_pipe[3] + 13'sd1)
              : exp_pipe[3];


// Correct fraction extraction
wire [51:0] frac_main = mant_norm[51:0];


// Rounding bits
wire guard = mant_prod[51];
wire round_bit = mant_prod[50];
wire sticky = |mant_prod[49:0];




// Round to nearest, ties to even
wire round_up = guard & (round_bit | sticky | frac_main[0]);

// Add rounding
wire [52:0] frac_round = {1'b0, frac_main} + {52'b0, round_up};
wire rounding_carry = frac_round[52];

// Final fraction and exponent
wire [51:0] frac_final = rounding_carry ? frac_round[52:1] : frac_round[51:0];
wire signed [12:0] exp_final = rounding_carry ? (exp_norm + 13'sd1) : exp_norm;

// Stage 4: Output register
always @(posedge clk) begin
    if (rst) begin
        result <= 0;
        mant_valid <= 0;
    end else begin
        if (mant_valid_internal) begin
            result <= {sign_pipe[3], exp_final[10:0], frac_final};
            mant_valid <= 1'b1;
        end else begin
            mant_valid <= 1'b0;
        end
    end
end




endmodule