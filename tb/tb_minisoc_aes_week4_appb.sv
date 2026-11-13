`timescale 1ns/1ps
// Testbench da Semana 4 (2/3): minisoc_aes_dp com o Apendice B da FIPS-197.
module tb_minisoc_aes_week4_appb;

  localparam logic [127:0] B_KEY = 128'h2b7e151628aed2a6abf7158809cf4f3c;
  localparam logic [127:0] B_PT  = 128'h3243f6a8885a308d313198a2e0370734;
  localparam logic [127:0] B_CT  = 128'h3925841d02dc09fbdc118597196a0b32;

  logic clk = 1'b0;
  logic rst_n;
  always #5 clk = ~clk;

  int errors = 0;
  int checks = 0;

  function automatic string hex128(input logic [127:0] v);
    return $sformatf("%016h%016h", v[127:64], v[63:0]);
  endfunction

  task automatic check(input string what, input logic [127:0] got, input logic [127:0] exp);
    checks++;
    if (got == exp) begin
      $display("  [OK]   %-24s %s", what, hex128(got));
    end else begin
      errors++;
      $display("  [ERRO] %-24s obtido %s, esperado %s", what, hex128(got), hex128(exp));
    end
  endtask

  task automatic finish_tb;
    $display("%0d conferencias, %0d erro(s)", checks, errors);
    if (errors == 0) begin
      $display("TEST RESULT: PASS");
    end else begin
      $display("TEST RESULT: FAIL");
      $fatal(1, "testbench falhou");
    end
    $finish;
  endtask

  initial begin
    #2_000_000;
    $display("TEST RESULT: FAIL (timeout)");
    $fatal(1, "timeout");
  end

  logic         key_load, decrypt, key_ready, blk_start, blk_done, busy;
  logic [127:0] key_in, blk_in, blk_out;
  minisoc_aes_dp dut (
    .clk_i(clk), .rst_n_i(rst_n),
    .key_load_i(key_load), .decrypt_i(decrypt), .key_i(key_in), .key_ready_o(key_ready),
    .blk_start_i(blk_start), .blk_i(blk_in), .blk_o(blk_out),
    .blk_done_o(blk_done), .busy_o(busy)
  );

  // carrega a chave e espera key_ready_o (com limite de ciclos)
  task automatic load_key(input logic [127:0] k, input logic dec);
    int n;
    @(negedge clk);
    key_in = k; decrypt = dec; key_load = 1'b1;
    @(negedge clk);
    key_load = 1'b0;
    n = 0;
    while (!key_ready && n < 30) begin @(negedge clk); n++; end
    checks++;
    if (!key_ready) begin errors++; $display("  [ERRO] key_ready_o nao subiu"); end
  endtask

  // processa um bloco e confere o estado do datapath ao fim de cada rodada.
  // exp[0] = estado apos a adicao inicial da chave; exp[r] = estado ao fim da rodada r; exp[10] = saida.
  task automatic run_block_rounds(input logic [127:0] din, input logic [10:0][127:0] exp);
    @(negedge clk);
    blk_in = din; blk_start = 1'b1;
    @(negedge clk);
    blk_start = 1'b0;
    check("inicial (AddRoundKey)", dut.state_q, exp[0]);
    for (int r = 1; r <= 10; r++) begin
      @(negedge clk);
      check($sformatf("fim da rodada %0d", r), dut.state_q, exp[r]);
    end
    checks++;
    if (!blk_done) begin errors++; $display("  [ERRO] blk_done_o nao subiu junto com a rodada 10"); end
    check("blk_o", blk_out, exp[10]);
  endtask

  // processa um bloco e confere so o resultado final (sem estados intermediarios)
  task automatic run_block_final(input logic [127:0] din, input logic [127:0] exp);
    int n;
    @(negedge clk);
    blk_in = din; blk_start = 1'b1;
    @(negedge clk);
    blk_start = 1'b0;
    n = 0;
    while (!blk_done && n < 30) begin @(negedge clk); n++; end
    check("blk_o", blk_out, exp);
  endtask

  task automatic reset_dp;
    rst_n = 1'b0; key_load = 1'b0; blk_start = 1'b0; decrypt = 1'b0;
    key_in = '0; blk_in = '0;
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
  endtask

  logic [10:0][127:0] ENC;

  initial begin
    ENC[0] = 128'h193de3bea0f4e22b9ac68d2ae9f84808;
    ENC[1] = 128'ha49c7ff2689f352b6b5bea43026a5049;
    ENC[2] = 128'haa8f5f0361dde3ef82d24ad26832469a;
    ENC[3] = 128'h486c4eee671d9d0d4de3b138d65f58e7;
    ENC[4] = 128'he0927fe8c86363c0d9b1355085b8be01;
    ENC[5] = 128'hf1006f55c1924cef7cc88b325db5d50c;
    ENC[6] = 128'h260e2e173d41b77de86472a9fdd28b25;
    ENC[7] = 128'h5a4142b11949dc1fa3e019657a8c040c;
    ENC[8] = 128'hea835cf00445332d655d98ad8596b0c5;
    ENC[9] = 128'heb40f21e592e38848ba113e71bc342d2;
    ENC[10] = 128'h3925841d02dc09fbdc118597196a0b32;

    reset_dp();

    $display("[Apendice B: cifragem]");
    load_key(B_KEY, 1'b0);
    run_block_rounds(B_PT, ENC);

    $display("[Apendice B: decifragem]");
    load_key(B_KEY, 1'b1);
    run_block_final(B_CT, B_PT);

    finish_tb();
  end

endmodule
