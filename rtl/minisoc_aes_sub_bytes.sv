// minisoc_aes_sub_bytes -- transformação SubBytes (FIPS-197, seção 5.1.1)
// Estado de 128 bits, puramente combinacional: 16 instâncias da S-box.
// Convenção do estado: byte n em [127-8n -: 8] (byte 0 em [127:120],
module minisoc_aes_sub_bytes (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);

  for (genvar n = 0; n < 16; n++) begin : g_sbox
    minisoc_aes_sbox u_sbox (
      .data_i (state_i[127 - 8*n -: 8]),
      .data_o (state_o[127 - 8*n -: 8])
    );
  end

endmodule
