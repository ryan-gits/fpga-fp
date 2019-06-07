module fp_add (
  input logic         clk,
  input logic         rst,
  input logic         in_vld,
  input logic [31:0]  a,
  input logic [31:0]  b,
  output logic        sum_vld,
  output logic [31:0] sum
);

  logic sign_bit_q;
  logic sign_bit_q2;
  logic sign_bit_q3;

  logic [7:0] a_exp;
  logic [7:0] b_exp;
  logic [7:0] exp_norm;
  logic [7:0] exp_norm_q;
  logic [7:0] exp_norm_q2;

  logic       a_exp_larger;

  logic [7:0] exp_diff;

  logic [22:0] a_mant_q;
  logic [22:0] b_mant_q;
  logic [23:0] a_mant_norm;
  logic [23:0] b_mant_norm;
  logic [22:0] sum_mant;

  logic        hidden_ovfl;
  logic        hidden_mant;

  logic [2:0] sum_vld_sr;

  assign a_exp = a[30:23];
  assign b_exp = b[30:23];

  always_ff @(posedge clk) begin
    sum_vld_sr <= {sum_vld_sr[$size(sum_vld_sr)-2:0], in_vld};
    a_mant_q   <= a[22:0];
    b_mant_q   <= b[22:0];

    // 1
    if (a_exp >= b_exp) begin
      a_exp_larger <= 1;
      exp_norm     <= b_exp;
      exp_diff     <= a_exp - b_exp;
    end else begin
      a_exp_larger <= 0;
      exp_norm     <= a_exp;
      exp_diff     <= b_exp - a_exp;
    end

    // 2
    exp_norm_q   <= exp_norm;
    a_mant_norm  <= (a_exp_larger || exp_diff == 0)  ? {1'b1, a_mant_q} : {1'b1, a_mant_q} >> exp_diff;
    b_mant_norm  <= (!a_exp_larger || exp_diff == 0) ? {1'b1, b_mant_q} : {1'b1, b_mant_q} >> exp_diff;

    // 3
    exp_norm_q2                          <= exp_norm_q;
    {hidden_ovfl, hidden_mant, sum_mant} <= a_mant_norm + b_mant_norm;

    // 4
    sum_vld <= sum_vld_sr[$size(sum_vld_sr)-1];
    sum     <= hidden_ovfl ? {1'b0, exp_norm_q2 + 1, sum_mant >> 1} : {1'b0, exp_norm_q2, sum_mant};
  end

endmodule
