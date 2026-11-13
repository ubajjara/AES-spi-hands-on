// minisoc_aes_key_exp -- um passo da expansão de chave AES-128, nos dois sentidos (FIPS-197, 5.2).
module minisoc_aes_key_exp (
  input  logic [127:0] rk_i,
  input  logic [3:0]   idx_i,    // índice da round key em rk_i (0..10)
  input  logic         inv_i,
  output logic [127:0] rk_o
);

  function automatic logic [7:0] rcon(input logic [3:0] i);   // Rcon[1..10]
    case (i)
      4'd1:    rcon = 8'h01;
      4'd2:    rcon = 8'h02;
      4'd3:    rcon = 8'h04;
      4'd4:    rcon = 8'h08;
      4'd5:    rcon = 8'h10;
      4'd6:    rcon = 8'h20;
      4'd7:    rcon = 8'h40;
      4'd8:    rcon = 8'h80;
      4'd9:    rcon = 8'h1b;
      4'd10:   rcon = 8'h36;
      default: rcon = 8'h00;
    endcase
  endfunction

  logic [31:0] w0, w1, w2, w3, sw_in, sw_out, t;

  assign {w0, w1, w2, w3} = rk_i;
  assign sw_in = inv_i ? (w3 ^ w2) : w3;

  for (genvar b = 0; b < 4; b++) begin : g_sbox     // RotWord + SubWord
    minisoc_aes_sbox u_sbox (
      .data_i (sw_in[31 - 8*((b + 1) % 4) -: 8]),
      .data_o (sw_out[31 - 8*b -: 8])
    );
  end

  assign t = sw_out ^ {rcon(inv_i ? idx_i : idx_i + 4'd1), 24'h000000};

  assign rk_o = inv_i ? {w0 ^ t, w1 ^ w0, w2 ^ w1, w3 ^ w2}
                      : {w0 ^ t, w1 ^ w0 ^ t, w2 ^ w1 ^ w0 ^ t, w3 ^ w2 ^ w1 ^ w0 ^ t};

endmodule