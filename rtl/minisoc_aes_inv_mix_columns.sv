// Puramente combinacional. Cada coluna c do estado é multiplicada, em GF(2^8), pela
// matriz circulante [0e 0b 0d 09], inversa da de MixColumns:

module minisoc_aes_inv_mix_columns (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);

  // Multiplicação por {02} em GF(2^8), polinômio x^8 + x^4 + x^3 + x + 1.
  function automatic logic [7:0] xtime(input logic [7:0] a);
    xtime = {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
  endfunction

  for (genvar c = 0; c < 4; c++) begin : g_col
    logic [7:0] s   [4];   // bytes da coluna c
    logic [7:0] x2  [4];
    logic [7:0] x4  [4];
    logic [7:0] x8  [4];
    logic [7:0] m9  [4];   // 09 * s[i]
    logic [7:0] m11 [4];   // 0b * s[i]
    logic [7:0] m13 [4];   // 0d * s[i]
    logic [7:0] m14 [4];   // 0e * s[i]

    for (genvar i = 0; i < 4; i++) begin : g_byte
      assign s[i]   = state_i[127 - 8*(4*c + i) -: 8];
      assign x2[i]  = xtime(s[i]);
      assign x4[i]  = xtime(x2[i]);
      assign x8[i]  = xtime(x4[i]);
      assign m9[i]  = x8[i] ^ s[i];
      assign m11[i] = x8[i] ^ x2[i] ^ s[i];
      assign m13[i] = x8[i] ^ x4[i] ^ s[i];
      assign m14[i] = x8[i] ^ x4[i] ^ x2[i];
    end

    assign state_o[127 - 8*(4*c + 0) -: 8] = m14[0] ^ m11[1] ^ m13[2] ^ m9[3];
    assign state_o[127 - 8*(4*c + 1) -: 8] = m9[0]  ^ m14[1] ^ m11[2] ^ m13[3];
    assign state_o[127 - 8*(4*c + 2) -: 8] = m13[0] ^ m9[1]  ^ m14[2] ^ m11[3];
    assign state_o[127 - 8*(4*c + 3) -: 8] = m11[0] ^ m13[1] ^ m9[2]  ^ m14[3];
  end

endmodule
