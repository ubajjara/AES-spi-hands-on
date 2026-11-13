`timescale 1ns/1ps
// Testbench da Semana 4 (1/3): minisoc_aes_key_exp, nos dois sentidos.
module tb_minisoc_aes_week4_key_exp;

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

  logic [127:0] ke_in, ke_out;
  logic [3:0]   ke_idx;
  logic         ke_inv;
  minisoc_aes_key_exp u_ke (.rk_i(ke_in), .idx_i(ke_idx), .inv_i(ke_inv), .rk_o(ke_out));

  logic [127:0] RKB [0:10];   // Apendice A.1, chave 2b7e1516...

  initial begin
    RKB[0] = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    RKB[1] = 128'ha0fafe1788542cb123a339392a6c7605;
    RKB[2] = 128'hf2c295f27a96b9435935807a7359f67f;
    RKB[3] = 128'h3d80477d4716fe3e1e237e446d7a883b;
    RKB[4] = 128'hef44a541a8525b7fb671253bdb0bad00;
    RKB[5] = 128'hd4d1c6f87c839d87caf2b8bc11f915bc;
    RKB[6] = 128'h6d88a37a110b3efddbf98641ca0093fd;
    RKB[7] = 128'h4e54f70e5f5fc9f384a64fb24ea6dc4f;
    RKB[8] = 128'head27321b58dbad2312bf5607f8d292f;
    RKB[9] = 128'hac7766f319fadc2128d12941575c006e;
    RKB[10] = 128'hd014f9a8c9ee2589e13f0cc8b6630ca6;

    rst_n = 1'b0; ke_in = '0; ke_idx = '0; ke_inv = 1'b0;

    $display("[key_exp: Apendice A.1 (chave B)]");
    for (int r = 0; r < 10; r++) begin
      ke_in = RKB[r];     ke_idx = r;     ke_inv = 1'b0;
      #1 check($sformatf("direto  K%0d -> K%0d", r, r + 1), ke_out, RKB[r + 1]);
      ke_in = RKB[r + 1]; ke_idx = r + 1; ke_inv = 1'b1;
      #1 check($sformatf("inverso K%0d -> K%0d", r + 1, r), ke_out, RKB[r]);
    end

    finish_tb();
  end

endmodule