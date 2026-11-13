`timescale 1ns/1ps
// Testbench da Semana 4 (3/3): minisoc_aes_dp com o Apendice C.1 da FIPS-197 (AES-128).
module tb_minisoc_aes_week4_appc;

  localparam logic [127:0] C1_KEY = 128'h000102030405060708090a0b0c0d0e0f;
  localparam logic [127:0] C1_PT  = 128'h00112233445566778899aabbccddeeff;
  localparam logic [127:0] C1_CT  = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

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
  logic [10:0][127:0] DEC;

  initial begin
    ENC[0] = 128'h00102030405060708090a0b0c0d0e0f0;
    ENC[1] = 128'h89d810e8855ace682d1843d8cb128fe4;
    ENC[2] = 128'h4915598f55e5d7a0daca94fa1f0a63f7;
    ENC[3] = 128'hfa636a2825b339c940668a3157244d17;
    ENC[4] = 128'h247240236966b3fa6ed2753288425b6c;
    ENC[5] = 128'hc81677bc9b7ac93b25027992b0261996;
    ENC[6] = 128'hc62fe109f75eedc3cc79395d84f9cf5d;
    ENC[7] = 128'hd1876c0f79c4300ab45594add66ff41f;
    ENC[8] = 128'hfde3bad205e5d0d73547964ef1fe37f1;
    ENC[9] = 128'hbd6e7c3df2b5779e0b61216e8b10b689;
    ENC[10] = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
    DEC[0] = 128'h7ad5fda789ef4e272bca100b3d9ff59f;
    DEC[1] = 128'h54d990a16ba09ab596bbf40ea111702f;
    DEC[2] = 128'h3e1c22c0b6fcbf768da85067f6170495;
    DEC[3] = 128'hb458124c68b68a014b99f82e5f15554c;
    DEC[4] = 128'he8dab6901477d4653ff7f5e2e747dd4f;
    DEC[5] = 128'h36339d50f9b539269f2c092dc4406d23;
    DEC[6] = 128'h2d6d7ef03f33e334093602dd5bfb12c7;
    DEC[7] = 128'h3bd92268fc74fb735767cbe0c0590e2d;
    DEC[8] = 128'ha7be1a6997ad739bd8c9ca451f618b61;
    DEC[9] = 128'h6353e08c0960e104cd70b751bacad0e7;
    DEC[10] = 128'h00112233445566778899aabbccddeeff;

    reset_dp();

    $display("[Apendice C.1: cifragem]");
    load_key(C1_KEY, 1'b0);
    run_block_rounds(C1_PT, ENC);

    $display("[Apendice C.1: decifragem]");
    load_key(C1_KEY, 1'b1);
    run_block_rounds(C1_CT, DEC);

    finish_tb();
  end

endmodule
