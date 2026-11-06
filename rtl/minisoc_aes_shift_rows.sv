// minisoc_aes_shift_rows -- transformação ShiftRows (FIPS-197, seção 5.1.2)

module minisoc_aes_shift_rows (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);

  logic [7:0] b [16];   // b[n] = byte n da entrada
  for (genvar n = 0; n < 16; n++) begin : g_unpack
    assign b[n] = state_i[127 - 8*n -: 8];
  end

  assign state_o = { b[0],  b[5],  b[10], b[15],   // coluna 0 da saída
                     b[4],  b[9],  b[14], b[3],    // coluna 1
                     b[8],  b[13], b[2],  b[7],    // coluna 2
                     b[12], b[1],  b[6],  b[11] }; // coluna 3

endmodule
