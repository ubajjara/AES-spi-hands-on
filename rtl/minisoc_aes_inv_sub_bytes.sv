// minisoc_aes_inv_sub_bytes -- transformação InvSubBytes (FIPS-197, seção 5.3.2)
module minisoc_aes_inv_sub_bytes (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);

  for (genvar n = 0; n < 16; n++) begin : g_inv_sbox
    minisoc_aes_inv_sbox u_inv_sbox (
      .data_i (state_i[127 - 8*n -: 8]),
      .data_o (state_o[127 - 8*n -: 8])
    );
  end

endmodule
