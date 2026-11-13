// minisoc_aes_dp -- datapath AES-128, uma rodada por ciclo, cifra e cifra inversa de um bloco.
module minisoc_aes_dp (
  input  logic         clk_i,
  input  logic         rst_n_i,

  input  logic         key_load_i,
  input  logic         decrypt_i,
  input  logic [127:0] key_i,
  output logic         key_ready_o,

  input  logic         blk_start_i,
  input  logic [127:0] blk_i,
  output logic [127:0] blk_o,
  output logic         blk_done_o,
  output logic         busy_o
);

  logic [127:0] state_q, rk_q, base_q;
  logic [3:0]   r_q;              // rodada em execução (1..10)
  logic [3:0]   idx_q;            // índice da round key em rk_q
  logic         dec_q, setup_q, busy_q, done_q, ready_q;

  logic         start, last;
  logic [127:0] rk_nxt;

  assign start = blk_start_i & ready_q & ~busy_q & ~key_load_i;
  assign last  = (r_q == 4'd10);

  // ---------------------------------------------------------------- round key
  minisoc_aes_key_exp u_key_exp (
    .rk_i  (rk_q),
    .idx_i (idx_q),
    .inv_i (dec_q & ~setup_q),    // o cálculo de K10 sempre anda para frente
    .rk_o  (rk_nxt)
  );

 // ---------------------------------------------------------------- adição inicial
  logic [127:0] init_state;
  minisoc_aes_add_round_key u_ark_i (.state_i(blk_i), .round_key_i(base_q), .state_o(init_state));

  // ---------------------------------------------------------------- rodada de cifragem
  logic [127:0] e_sb, e_sr, e_mc, e_pre, e_next;
  minisoc_aes_sub_bytes   u_sb (.state_i(state_q), .state_o(e_sb));
  minisoc_aes_shift_rows  u_sr (.state_i(e_sb),    .state_o(e_sr));
  minisoc_aes_mix_columns u_mc (.state_i(e_sr),    .state_o(e_mc));
  assign e_pre  = last ? e_sr : e_mc;                     // rodada 10 sem MixColumns
  minisoc_aes_add_round_key u_ark_e (.state_i(e_pre), .round_key_i(rk_nxt), .state_o(e_next));

   // ---------------------------------------------------------------- rodada de decifragem
  logic [127:0] d_sr, d_sb, d_ark, d_imc, d_next;
  minisoc_aes_inv_shift_rows  u_isr (.state_i(state_q), .state_o(d_sr));
  minisoc_aes_inv_sub_bytes   u_isb (.state_i(d_sr),    .state_o(d_sb));
  minisoc_aes_add_round_key   u_ark_d (.state_i(d_sb), .round_key_i(rk_nxt), .state_o(d_ark));
  minisoc_aes_inv_mix_columns u_imc (.state_i(d_ark),   .state_o(d_imc));
  assign d_next = last ? d_ark : d_imc;                   // rodada 10 sem InvMixColumns



  // ---------------------------------------------------------------- controle (com reset)
  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      setup_q <= 1'b0;
      ready_q <= 1'b0;
      busy_q  <= 1'b0;
      done_q  <= 1'b0;

    end else begin
      done_q <= 1'b0;

      if (key_load_i) begin
        setup_q <= decrypt_i;
        ready_q <= ~decrypt_i;

      end else if (setup_q && idx_q == 4'd9) begin
        setup_q <= 1'b0;
        ready_q <= 1'b1;

      end else if (start) begin
        busy_q <= 1'b1;

      end else if (busy_q && last) begin
        busy_q <= 1'b0;
        done_q <= 1'b1;

      end
    end
  end

  // ---------------------------------------------------------------- dados (sem reset)
  always_ff @(posedge clk_i) begin
    if (key_load_i) begin
      rk_q   <= key_i;
      base_q <= key_i;
      idx_q  <= 4'd0;
      dec_q  <= decrypt_i;

    end else if (setup_q) begin                            // K0 -> K10
      rk_q  <= rk_nxt;
      idx_q <= idx_q + 4'd1;
      if (idx_q == 4'd9) base_q <= rk_nxt;

    end else if (start) begin                              // adição inicial
      state_q <= init_state;
      rk_q    <= base_q;
      idx_q   <= dec_q ? 4'd10 : 4'd0;
      r_q     <= 4'd1;

    end else if (busy_q) begin                             // rodadas 1..10
      state_q <= dec_q ? d_next : e_next;
      rk_q    <= rk_nxt;
      idx_q   <= dec_q ? idx_q - 4'd1 : idx_q + 4'd1;
      r_q     <= r_q + 4'd1;

    end
  end

  assign key_ready_o = ready_q;
  assign blk_o       = state_q;
  assign blk_done_o  = done_q;
  assign busy_o      = busy_q;

endmodule