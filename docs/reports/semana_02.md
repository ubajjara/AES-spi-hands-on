# Semana 2 — SubBytes e ShiftRows

Entrega: 30/10/2026 · Tag: `w02-rtl-v1.0`

## 1. O que foi feito

| Arquivo | Conteúdo |
|---|---|
| `rtl/minisoc_aes_sbox.sv` | S-box, 8 → 8 bits, combinacional: tabela de 256 entradas da Figura 7 da FIPS-197 |
| `rtl/minisoc_aes_sub_bytes.sv` | SubBytes, estado de 128 bits, 16 instâncias da S-box |
| `rtl/minisoc_aes_shift_rows.sv` | ShiftRows, estado de 128 bits, só reordenação de fios |
| `tb/tb_minisoc_aes_week2.sv` | Testbench autoverificável |
| `tb/vectors/*.mem` | Referências extraídas do PDF da FIPS-197 (Figura 7 e Apêndice B) |


Convenções:
- Estado de 128 bits com o byte *n* em `[127-8n -: 8]` (byte 0 em `[127:120]`, byte 15 em `[7:0]`); byte *n* = `s[r][c]`, com `r = n mod 4` e `c = n div 4` (FIPS-197, seção 3.4).
- ShiftRows: `s'[r][c] = s[r][(c + r) mod 4]`, isto é, a linha *r* gira *r* posições para a esquerda.
- Portas: `data_i`/`data_o` na S-box e `state_i`/`state_o` nos módulos de estado.

## 2. Resultados obtidos

| Critério de aceite | Resultado |
|---|---|
| Testbench por um único comando | `make run` (VCS) |
| PASS nas 256 entradas da S-box | PASS (512 comparações: 256 contra a Figura 7 e 256 contra um modelo GF(2^8) no testbench; mais `00 → 63` e `53 → ed`) |
| PASS nos vetores do Apêndice B | PASS, rodadas 1 a 10 (Start → After SubBytes → After ShiftRows) |
| Lint sem erros | `vlogan` com `+lint=all`: nenhuma mensagem nos três módulos de RTL |

Total: 544 conferências, 0 erros. Para cada rodada o testbench confere `SubBytes(start) = after_sub`, `ShiftRows(after_sub) = after_shift` e a cadeia SubBytes → ShiftRows em série. A rodada 10 não tem MixColumns, então o Apêndice B termina em After ShiftRows.

**Lint.** O `vlogan +lint=all` emitiu 4 avisos `Lint-[NS] Null statement`, todos no testbench (linhas 91, 95, 96 e 107, de um `#1;` isolado). São de estilo, não afetam o resultado e ficam fora do RTL, que em sguida foram corrigidos.

**Como a verificação foi conferida**
- A tabela do RTL e o `.mem` do testbench vêm da mesma figura, então essa comparação pega erros de transcrição e de fiação, mas não um erro da própria figura. A conferência independente é o modelo GF(2^8) dentro do testbench (inversa + transformação afim), que também bate nas 256 entradas. O script de extração confere a figura e o Apêndice B contra um modelo em Python antes de gravar os `.mem`.
- O testbench detecta defeitos: quatro mutações no RTL (uma entrada da S-box errada, ShiftRows girando para o lado oposto, ordem dos bytes invertida no SubBytes, índice de origem do ShiftRows trocado) terminam em `FAIL`.
- Conferência adicional fora do fluxo do curso: o mesmo testbench compila e passa no Icarus Verilog 12.0 e no Verilator 5.020 (`--lint-only -Wall` sem avisos no RTL).

## 3. Problemas encontrados

- **Array de constantes para a S-box.** A forma `localparam logic [7:0] SBOX [256] = '{...}` é aceita pelo Verilator, mas não pelo Icarus 12, e a versão empacotada ascendente (`[0:255]`) gera aviso `ASCRANGE` no lint. A S-box ficou como `case` de 256 entradas, que roda em qualquer ferramenta.
- **`unique case` na S-box.** Gerava aviso de simulação em t=0, quando as entradas ainda são X. Como o datapath vai ter estados X antes do reset, troquei por `case` simples (a tabela cobre os 256 valores, então não há latch).
- **Avisos `Lint-[NS]` no testbench.** Os `#1;` isolados disparam o aviso. Opcional: prender o atraso à instrução seguinte (`#1 check8(...)`).

## 4. Próximos passos

- Semana 3: datapath `minisoc_aes_dp`, reaproveitando as três peças; faltam MixColumns e AddRoundKey, e só então dá para comparar a cifragem completa com o resultado final do Apêndice B.
- Decifragem é exigida pelo Block Guide (`AES_CONTROL.DECRYPT`, seções 6.1 e 8.1): criar a S-box inversa, InvSubBytes, InvShiftRows e, no datapath, InvMixColumns.
- Reaproveitar `minisoc_aes_sbox` na expansão de chave (`minisoc_aes_key_exp`, passo SubWord da FIPS-197).
- Resolver com o verificador/orientador as dúvidas 1 e 3 abaixo (local dos arquivos e meta de temporização).
- Na síntese, comparar a S-box em `case` com uma S-box calculada (campo composto GF((2^4)^2)) se houver meta de área.
- Opcional: teste com estados aleatórios usando um modelo de referência no testbench.

## Dúvidas sobre o Block Guide

Leitura das seções 1 a 3 e 8 do Block Guide v1.0.0 (lidas também as seções 6, 7 e 10, que definem formato de dados e organização do RTL).

**O que o Block Guide resolve**

1. **Ordem dos bytes.** A seção 7.1 coloca a Word 0 do bloco em `[127:96]` e dá o exemplo `128'h00112233…EEFF`, com `mem[0] = 0x00112233`. Logo o byte 0 (`00`) fica em `[127:120]`, exatamente a convenção usada no RTL e na FIPS-197. `KEY0` e `IV0` seguem o mesmo padrão (`cfg_key[127:96]`, `cfg_iv[127:96]`).
2. **Decifragem é exigida.** `AES_CONTROL.DECRYPT` (6.1) e o texto da 8.1 ("cipher e inverse cipher") pedem o caminho inverso. Para esta semana o escopo continua sendo só o sentido direto; as versões inversas entram nos próximos passos.
3. **Nomes de portas.** O guia só define as interfaces de topo e os arquivos principais, e não cita S-box, SubBytes nem ShiftRows. `data_i/data_o` e `state_i/state_o` podem ficar como estão.

**Ambiguidades e dúvidas em aberto**

1. **Local e nome dos módulos.** A seção 10 lista só `minisoc_aes_dp.sv`, `minisoc_aes_key_exp.sv` e `minisoc_aes_top.sv` em `rtl/minisoc_aes/`. Não diz se S-box, SubBytes e ShiftRows ficam em arquivos próprios ou dentro do datapath, nem se os nomes `minisoc_aes_sbox/sub_bytes/shift_rows` são os esperados. O guia também mostra subpastas, enquanto o repositório está com `rtl/` plano.


## Como reproduzir

Da raiz do repositório (os `.mem` são lidos por caminho relativo, `tb/vectors/...`):

```
make syntax   # vlogan +lint=all nos módulos de RTL
make run     # compila (vlogan + vcs) e roda o testbench; esperado: TEST RESULT: PASS
```
