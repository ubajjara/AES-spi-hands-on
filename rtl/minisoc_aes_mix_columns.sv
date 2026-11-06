// minisoc_aes_mix_columns -- transformação MixColumns (FIPS-197, seção 5.1.3)
module minisoc_aes_mix_columns (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);

  // Multiplicação por {02} em GF(2^8), polinômio x^8 + x^4 + x^3 + x + 1.
  function automatic logic [7:0] xtime(input logic [7:0] a);
    xtime = {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
  endfunction

  for (genvar c = 0; c < 4; c++) begin : g_col
    logic [7:0] s [4];   // bytes da coluna c
    logic [7:0] x [4];   // 02 * s[i]

    for (genvar i = 0; i < 4; i++) begin : g_byte
      assign s[i] = state_i[127 - 8*(4*c + i) -: 8];
      assign x[i] = xtime(s[i]);
    end

    assign state_o[127 - 8*(4*c + 0) -: 8] = x[0] ^ (x[1] ^ s[1]) ^ s[2] ^ s[3];
    assign state_o[127 - 8*(4*c + 1) -: 8] = s[0] ^ x[1] ^ (x[2] ^ s[2]) ^ s[3];
    assign state_o[127 - 8*(4*c + 2) -: 8] = s[0] ^ s[1] ^ x[2] ^ (x[3] ^ s[3]);
    assign state_o[127 - 8*(4*c + 3) -: 8] = (x[0] ^ s[0]) ^ s[1] ^ s[2] ^ x[3];
  end

endmodule
