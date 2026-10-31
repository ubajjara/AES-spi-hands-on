// Testbench autoverificável da Semana 2: S-box, SubBytes e ShiftRows.
//
//  (a) S-box nas 256 entradas, comparada com (1) a Figura 7 da FIPS-197
//      (tb/vectors/fips197_sbox.mem, extraída do PDF) e (2) um modelo
//      comportamental independente (inversa em GF(2^8) + transformação afim).
//  (b) SubBytes e ShiftRows nos estados do Apêndice B (rodadas 1 a 10), em três
//      conferências por rodada: SubBytes(start) == after_sub,
//      ShiftRows(after_sub) == after_shift e a cadeia start -> after_shift.
//
// Termina com "TEST RESULT: PASS" ou "TEST RESULT: FAIL" e, em falha, $fatal.
`timescale 1ns/1ps

module tb_minisoc_aes_week2;

  localparam string SBOX_MEM = "tb/vectors/fips197_sbox.mem";
  localparam string APPB_MEM = "tb/vectors/fips197_appb.mem";
  localparam int    NROUNDS  = 10;

  // ---------------------------------------------------------------- DUTs
  logic [7:0]   sbox_in,  sbox_out;
  logic [127:0] sb_in,    sb_out;
  logic [127:0] sr_in,    sr_out;
  logic [127:0] chain_sb, chain_sr;   // SubBytes -> ShiftRows encadeados

  minisoc_aes_sbox       u_sbox  (.data_i(sbox_in), .data_o(sbox_out));
  minisoc_aes_sub_bytes  u_sb    (.state_i(sb_in),  .state_o(sb_out));
  minisoc_aes_shift_rows u_sr    (.state_i(sr_in),  .state_o(sr_out));

  minisoc_aes_sub_bytes  u_sb_c  (.state_i(sb_in),     .state_o(chain_sb));
  minisoc_aes_shift_rows u_sr_c  (.state_i(chain_sb),  .state_o(chain_sr));

  // ------------------------------------------- modelo de referência (GF)
  function automatic logic [7:0] xtime(input logic [7:0] a);
    xtime = {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
  endfunction

  function automatic logic [7:0] gmul(input logic [7:0] a_in, input logic [7:0] b_in);
    logic [7:0] a, b, p;
    a = a_in; b = b_in; p = 8'h00;
    for (int i = 0; i < 8; i++) begin
      if (b[0]) p = p ^ a;
      a = xtime(a);
      b = b >> 1;
    end
    gmul = p;
  endfunction

  function automatic logic [7:0] rotl8(input logic [7:0] x, input int n);
    rotl8 = (x << n) | (x >> (8 - n));
  endfunction

  function automatic logic [7:0] sbox_model(input logic [7:0] x);
    logic [7:0] inv;
    inv = 8'h01;
    for (int i = 0; i < 254; i++) inv = gmul(inv, x);   // x^254; 0 -> 0
    sbox_model = inv ^ rotl8(inv, 1) ^ rotl8(inv, 2) ^ rotl8(inv, 3)
                     ^ rotl8(inv, 4) ^ 8'h63;
  endfunction

  // ------------------------------------------------------------ checagem
  logic [7:0]   sbox_ref [0:255];
  logic [127:0] appb     [0:3*NROUNDS-1];
  int errors = 0;
  int checks = 0;

  task automatic check128(input string what, input logic [127:0] got,
                          input logic [127:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $display("ERROR %s: obtido %032h, esperado %032h", what, got, exp);
    end
  endtask

  task automatic check8(input string what, input logic [7:0] x,
                        input logic [7:0] got, input logic [7:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $display("ERROR %s(%02h): obtido %02h, esperado %02h", what, x, got, exp);
    end
  endtask

  initial begin
    $readmemh(SBOX_MEM, sbox_ref);
    $readmemh(APPB_MEM, appb);

    // ---------------- (a) S-box, 256 entradas
    for (int i = 0; i < 256; i++) begin
      sbox_in = i[7:0];
      #1
      check8("sbox vs FIPS-197 Fig.7", sbox_in, sbox_out, sbox_ref[i]);
      check8("sbox vs modelo GF",      sbox_in, sbox_out, sbox_model(sbox_in));
    end
    sbox_in = 8'h00; #1 check8("sbox spot", sbox_in, sbox_out, 8'h63);
    sbox_in = 8'h53; #1 check8("sbox spot", sbox_in, sbox_out, 8'hed);
    $display("S-box: 256 entradas verificadas (+ spot checks 00->63, 53->ed)");

    // ---------------- (b) SubBytes / ShiftRows, Apêndice B, rodadas 1..10
    for (int k = 1; k <= NROUNDS; k++) begin
      logic [127:0] st, sub, shf;
      st  = appb[3*(k-1) + 0];
      sub = appb[3*(k-1) + 1];
      shf = appb[3*(k-1) + 2];

      sb_in = st;  sr_in = sub;
      #1
      check128($sformatf("rodada %0d SubBytes",        k), sb_out,    sub);
      check128($sformatf("rodada %0d ShiftRows",       k), sr_out,    shf);
      check128($sformatf("rodada %0d SubBytes->ShiftRows", k), chain_sr, shf);
      $display("Rodada %2d: start %032h -> sub %032h -> shift %032h", k, st, sub, shf);
    end

    // ---------------- resultado
    $display("%0d conferências, %0d erro(s)", checks, errors);
    if (errors == 0) begin
      $display("TEST RESULT: PASS");
    end else begin
      $display("TEST RESULT: FAIL");
      $fatal(1, "testbench falhou");
    end
    $finish;
  end

endmodule
