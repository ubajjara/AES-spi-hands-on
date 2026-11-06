
module minisoc_aes_add_round_key (
  input  logic [127:0] state_i,
  input  logic [127:0] round_key_i,
  output logic [127:0] state_o
);

  assign state_o = state_i ^ round_key_i;

endmodule
