module fp_add (
  input logic         clk,
  input logic         rst,
  input logic         in_vld,
  input logic [31:0]  a,
  input logic [31:0]  b,
  output logic        sum_vld,
  output logic [31:0] sum
);

  logic [7:0] exp_a;
  logic [7:0] exp_b;
  logic [7:0] exp_a_norm;
  logic [7:0] exp_b_norm;
  logic [7:0] exp_a_norm_q;
  logic [7:0] exp_b_norm_q;
  logic [7:0] exp_a_norm_q2;
  logic [7:0] exp_b_norm_q2;

  logic       exp_a_larger;

  logic [7:0] exp_diff;

  logic [22:0] a_mant_q;
  logic [22:0] b_mant_q;
  logic [23:0] a_mant_norm;
  logic [23:0] b_mant_norm;
  logic [22:0] sum_mant;

  logic        hidden_ovfl;
  logic        hidden_mant;

  logic [2:0] sum_vld_sr;

  assign exp_a = a[30:23];
  assign exp_b = b[30:23];

  always_ff @(posedge clk) begin
    sum_vld_sr <= {sum_vld_sr[$size(sum_vld_sr)-2:0], in_vld};
    a_mant_q   <= a[22:0];
    b_mant_q   <= b[22:0];

    // 1
    if (exp_a >= exp_b) begin
      exp_a_larger <= 1;
      exp_b_norm   <= exp_a;
      exp_a_norm   <= exp_a;
      exp_diff     <= exp_a - exp_b;
    end else begin
      exp_a_larger <= 0;
      exp_a_norm   <= exp_b;
      exp_b_norm   <= exp_b;
      exp_diff     <= exp_b - exp_a;
    end

    // 2
    exp_a_norm_q <= exp_a_norm;
    exp_b_norm_q <= exp_b_norm;
    a_mant_norm  <= (exp_a_larger || exp_diff == 0)  ? {1'b1, a_mant_q} : {1'b1, a_mant_q} >> exp_diff;
    b_mant_norm  <= (!exp_a_larger || exp_diff == 0) ? {1'b1, b_mant_q} : {1'b1, b_mant_q} >> exp_diff;

    // 3
    exp_a_norm_q2                        <= exp_a_norm_q;
    exp_b_norm_q2                        <= exp_b_norm_q;
    {hidden_ovfl, hidden_mant, sum_mant} <= a_mant_norm + b_mant_norm;

    // 4
    sum_vld <= sum_vld_sr[$size(sum_vld_sr)-1];
    sum     <= hidden_ovfl ? {1'b0, exp_a_norm_q2 + 1, sum_mant >> 1} : {1'b0, exp_a_norm_q2, sum_mant};
  end

endmodule
