// Todos os vetores estão neste arquivo. Estado: byte 0 em [127:120], byte 15 em [7:0].
`timescale 1ns/1ps
 
module tb_minisoc_aes_week3;
 
  // Apêndice B, rodada 1 (cifragem)
  localparam logic [127:0] B_S_ROW   = 128'hd4bf5d30e0b452aeb84111f11e2798e5;
  localparam logic [127:0] B_M_COL   = 128'h046681e5e0cb199a48f8d37a2806264c;
  localparam logic [127:0] B_KEY1    = 128'ha0fafe1788542cb123a339392a6c7605;
  localparam logic [127:0] B_START2  = 128'ha49c7ff2689f352b6b5bea43026a5049;
 
  // Apêndice C.1, rodada 1 (cifra inversa)
  localparam logic [127:0] C_ISTART  = 128'h7ad5fda789ef4e272bca100b3d9ff59f;
  localparam logic [127:0] C_IS_ROW  = 128'h7a9f102789d5f50b2beffd9f3dca4ea7;
  localparam logic [127:0] C_IS_BOX  = 128'hbd6e7c3df2b5779e0b61216e8b10b689;
  localparam logic [127:0] C_KEY     = 128'h549932d1f08557681093ed9cbe2c974e;
  localparam logic [127:0] C_IK_ADD  = 128'he9f74eec023020f61bf2ccf2353c21c7;
  localparam logic [127:0] C_ISTART2 = 128'h54d990a16ba09ab596bbf40ea111702f;
 
  logic [7:0]   sbox_in, sbox_out, isbox_in, isbox_out;
  logic [127:0] mc_in, mc_out, imc_in, imc_out;
  logic [127:0] isr_in, isr_out, isb_in, isb_out;
  logic [127:0] ark_in, ark_key, ark_out;
 
  minisoc_aes_sbox            u_sbox  (.data_i(sbox_in),  .data_o(sbox_out));
  minisoc_aes_inv_sbox        u_isbox (.data_i(isbox_in), .data_o(isbox_out));
  minisoc_aes_mix_columns     u_mc    (.state_i(mc_in),   .state_o(mc_out));
  minisoc_aes_inv_mix_columns u_imc   (.state_i(imc_in),  .state_o(imc_out));
  minisoc_aes_inv_shift_rows  u_isr   (.state_i(isr_in),  .state_o(isr_out));
  minisoc_aes_inv_sub_bytes   u_isb   (.state_i(isb_in),  .state_o(isb_out));
  minisoc_aes_add_round_key   u_ark   (.state_i(ark_in), .round_key_i(ark_key), .state_o(ark_out));
 
  int errors = 0;
  int checks = 0;
 
  // Texto hexadecimal de 32 dígitos, em duas metades (mantém os zeros à esquerda).
  function automatic string hex128(input logic [127:0] v);
    return $sformatf("%016h%016h", v[127:64], v[63:0]);
  endfunction
 
  // Verificação com impressão: nome, entrada e saída obtida.
  task automatic chk(input string what, input logic [127:0] inp,
                     input logic [127:0] got, input logic [127:0] exp);
    checks++;
    if (got === exp) begin
      $display("  [OK]   %-15s %s -> %s", what, hex128(inp), hex128(got));
    end else begin
      errors++;
      $display("  [ERRO] %-15s %s -> obtido %s, esperado %s", what, hex128(inp), hex128(got), hex128(exp));
    end
  endtask
 
  // Verificação silenciosa, para os laços (só imprime se errar).
  task automatic chk_q(input string what, input logic [127:0] got, input logic [127:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $display("  [ERRO] %s: obtido %s, esperado %s", what, hex128(got), hex128(exp));
    end
  endtask
 
  initial begin
    int err0;
    $display("==================================================================");
    $display(" TESTBENCH SEMANA 3: transformações de rodada (FIPS-197)");
    $display("==================================================================");
 
    $display("[Apêndice B, rodada 1: cifragem]");
    mc_in  = B_S_ROW;
    ark_in = B_M_COL; ark_key = B_KEY1;
    #1 chk("MixColumns",  B_S_ROW, mc_out,  B_M_COL);
    chk("AddRoundKey",    B_M_COL, ark_out, B_START2);
 
    $display("[Apêndice C.1, rodada 1: cifra inversa]");
    isr_in = C_ISTART;
    isb_in = C_IS_ROW;
    ark_in = C_IS_BOX; ark_key = C_KEY;
    imc_in = C_IK_ADD;
    #1 chk("InvShiftRows", C_ISTART, isr_out, C_IS_ROW);
    chk("InvSubBytes",     C_IS_ROW, isb_out, C_IS_BOX);
    chk("AddRoundKey",     C_IS_BOX, ark_out, C_IK_ADD);
    chk("InvMixColumns",   C_IK_ADD, imc_out, C_ISTART2);
 
    $display("[S-box inversa: InvSBox(SBox(x)) = x, x de 00 a ff]");
    err0 = errors;
    for (int i = 0; i < 256; i++) begin
      sbox_in = i[7:0];
      #1 isbox_in = sbox_out;
      #1 chk_q($sformatf("inv_sbox(sbox(%02h))", i), {120'b0, isbox_out}, {120'b0, i[7:0]});
    end
    $display("  [%s] 256 entradas conferidas, %0d erro(s)", (errors == err0) ? "OK" : "ERRO", errors - err0);
 
    $display("[InvMixColumns(MixColumns(x)) = x, estados aleatórios]");
    err0 = errors;
    for (int k = 0; k < 200; k++) begin
      mc_in = {$urandom, $urandom, $urandom, $urandom};
      #1 imc_in = mc_out;
      #1 chk_q("InvMixColumns(MixColumns(x))", imc_out, mc_in);
    end
    $display("  [%s] 200 estados conferidos, %0d erro(s)", (errors == err0) ? "OK" : "ERRO", errors - err0);
 
    $display("------------------------------------------------------------------");
    $display("%0d conferências, %0d erro(s)", checks, errors);
    if (errors == 0) $display("TEST RESULT: PASS");
    else             $display("TEST RESULT: FAIL");
    $finish;
  end
 
endmodule