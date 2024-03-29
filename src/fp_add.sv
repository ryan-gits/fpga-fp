module fp_add (
  input logic         clk,
  input logic         rst,
  input logic         in_vld,
  input logic [31:0]  a,
  input logic [31:0]  b,
  output logic        sum_vld,
  output logic [31:0] sum
);

  localparam OVFL_BIT_POS     = 24;
  localparam IMPLICIT_BIT_POS = 23;
  localparam PIPELINE_DLY     = 8;

  logic a_sign_q;
  logic a_sign_q2;
  logic b_sign_q;
  logic b_sign_q2;

  logic [7:0] a_exp;
  logic [7:0] b_exp;
  logic [7:0] exp_norm;
  logic [7:0] exp_norm_q;
  logic [7:0] exp_norm_q2;
  logic [7:0] exp_norm_q3;
  logic [7:0] exp_norm_q4;
  logic [7:0] exp_norm_adj;

  logic a_exp_larger;

  logic [7:0] exp_diff;

  logic [22:0] a_mant_q;
  logic [22:0] b_mant_q;
  logic [23:0] a_mant_norm;
  logic [23:0] b_mant_norm;
  logic [22:0] sum_mant_adj;

  logic signed [24:0] a_mant_norm_signed;
  logic signed [24:0] b_mant_norm_signed;
  logic signed [25:0] sum_mant_signed;
  logic        [24:0] sum_mant_unsigned;

  logic [PIPELINE_DLY-1:0] sum_vld_sr;

  logic final_sign;
  logic final_sign_q;
  logic final_sign_q2;

  logic imp_bit;

  logic [4:0] mant_msb;

  assign a_exp = a[30:23];
  assign b_exp = b[30:23];

  always_ff @(posedge clk) begin
    if (rst) begin
      sum_vld_sr <= '0;
    end else begin
      sum_vld_sr <= {sum_vld_sr[$size(sum_vld_sr)-2:0], in_vld};
    end
  end

  assign sum_vld = sum_vld_sr[$size(sum_vld_sr)-1];

  always_ff @(posedge clk) begin
    a_sign_q <= a[31];
    b_sign_q <= b[31];
    a_mant_q <= a[22:0];
    b_mant_q <= b[22:0];

    // 1, determine largest exp and difference between two
    if (a_exp >= b_exp) begin
      a_exp_larger <= 1;
      exp_norm     <= a_exp;
      exp_diff     <= a_exp - b_exp;
    end else begin
      a_exp_larger <= 0;
      exp_norm     <= b_exp;
      exp_diff     <= b_exp - a_exp;
    end

    // 2, add implicit mantissa bit and normalize
    a_sign_q2   <= a_sign_q;
    b_sign_q2   <= b_sign_q;
    exp_norm_q  <= exp_norm;
    a_mant_norm <= (a_exp_larger ) ? {1'b1, a_mant_q} : {1'b1, a_mant_q} >> exp_diff;
    b_mant_norm <= (!a_exp_larger) ? {1'b1, b_mant_q} : {1'b1, b_mant_q} >> exp_diff;

    // Q0.23, mantissa sign conversion
    exp_norm_q2        <= exp_norm_q;
    a_mant_norm_signed <= a_sign_q2 ? -a_mant_norm : a_mant_norm;
    b_mant_norm_signed <= b_sign_q2 ? -b_mant_norm : b_mant_norm;

    // Q1.23, perform signed mantissa addition
    exp_norm_q3     <= exp_norm_q2;
    final_sign      <= sum_mant_signed[$size(sum_mant_signed)-1];
    sum_mant_signed <= a_mant_norm_signed + b_mant_norm_signed;

    // Q2.23, convert to unsigned, sum_mant_unsigned[24] = overflow, [23] = implicit
    final_sign_q      <= final_sign;
    exp_norm_q4       <= exp_norm_q3;
    sum_mant_unsigned <= sum_mant_signed[$size(sum_mant_signed)-1] ? -sum_mant_signed : sum_mant_signed[$size(sum_mant_signed)-2:0];

    final_sign_q2 <= final_sign_q;
    // implicit bit or overflow not set, need to normalize
    if (!sum_mant_unsigned[OVFL_BIT_POS] && !sum_mant_unsigned[IMPLICIT_BIT_POS]) begin
      // special case where mantissa is 0, set exponent to 0, no valid shifts possible
      if (sum_mant_unsigned[$size(sum_mant_adj)-1:0] == '0) begin
        sum_mant_adj <= '0;
        exp_norm_adj <= '0;
      // find msb in mantissa, subtract that value from exponent and shift msb into implicit position
      end else begin
        sum_mant_adj <= sum_mant_unsigned[$size(sum_mant_adj)-1:0] << ($size(sum_mant_adj) - mant_msb);
        exp_norm_adj <= exp_norm_q4 - ($size(sum_mant_adj) - mant_msb);
      end
    // overflowed implicit, adjust exponent
    end else if (sum_mant_unsigned[OVFL_BIT_POS]) begin
      exp_norm_adj <= exp_norm_q4 + 1;
      sum_mant_adj <= sum_mant_unsigned[$size(sum_mant_adj)-1:0] >> 1;
    // already normalized, implicit set, no overflow
    end else begin
      exp_norm_adj <= exp_norm_q4;
      sum_mant_adj <= sum_mant_unsigned[$size(sum_mant_adj)-1:0];
    end

    // 4, carry/increment exponent and shift mantissa if implicit leading bit overflowed
    sum <= {final_sign_q2, exp_norm_adj, sum_mant_adj};
  end

  // find highest msb of mantissa sum
  always_comb begin
    mant_msb = 0;

    for (int i = 0; i < $size(sum_mant_adj)-1; i++) begin
      if (sum_mant_unsigned[i]) begin
        mant_msb = i;
      end
    end
  end
endmodule

