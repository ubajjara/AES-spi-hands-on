# Relatório de Estudo — AES e SPI

**Projeto:** Acelerador AES com interface SPI e baixo consumo (trilha RTL Design)
**Objetivo:** consolidar o estudo do algoritmo AES (FIPS 197) e do protocolo SPI, que fundamentam a arquitetura e o RTL das próximas semanas.

---

## 1. AES — Advanced Encryption Standard (FIPS 197)

### 1.1 Visão geral

O AES é uma cifra **simétrica de blocos**, baseada no algoritmo Rijndael e padronizada pelo NIST no FIPS 197. A mesma chave é usada para cifrar e decifrar. O bloco processado tem sempre **128 bits** (16 bytes), independentemente do tamanho da chave.

| Variante | Chave (Nk) | Bloco (Nb) | Rodadas (Nr) |
| :--- | :---: | :---: | :---: |
| AES-128 | 128 bits (4 words) | 128 bits (4 words) | 10 |
| AES-192 | 192 bits (6 words) | 128 bits (4 words) | 12 |
| AES-256 | 256 bits (8 words) | 128 bits (4 words) | 14 |

Uma *word* tem 32 bits (4 bytes). O AES especifica apenas a transformação de **um bloco**; modos de operação (CBC, CTR etc.) definem como aplicá-lo a mensagens maiores e não fazem parte deste estudo.

Terminologia: *plaintext* (dado original), *ciphertext* (dado cifrado), *Cipher Key* (chave original), *Round Keys* (chaves de rodada derivadas por Key Expansion) e *State* (estado intermediário).

### 1.2 O State

O bloco de entrada é copiado para uma matriz 4×4 de bytes, o **State**, preenchida **por colunas**: os quatro primeiros bytes formam a coluna 0, os quatro seguintes a coluna 1, e assim por diante.

| | c0 | c1 | c2 | c3 |
| :---: | :---: | :---: | :---: | :---: |
| **r0** | B0 | B4 | B8 | B12 |
| **r1** | B1 | B5 | B9 | B13 |
| **r2** | B2 | B6 | B10 | B14 |
| **r3** | B3 | B7 | B11 | B15 |

Ao final da cifragem, o State é convertido de volta para uma sequência de 16 bytes (o ciphertext), na mesma ordem por colunas. Em hardware, a correspondência entre os bits do barramento e as posições do State precisa ser mantida e documentada; um erro de ordenação gera resultado incorreto mesmo com todas as transformações corretas.

### 1.3 Aritmética em GF(2⁸)

Os bytes são tratados como polinômios de grau ≤ 7 sobre GF(2). A **adição** é o XOR. A **multiplicação** é feita módulo o polinômio irredutível

```
m(x) = x⁸ + x⁴ + x³ + x + 1   (0x11B)
```

A multiplicação por `{02}` (*xtime*) é um deslocamento de 1 bit à esquerda, seguido de XOR com `0x1B` se o bit mais significativo original era 1. A multiplicação por `{03}` é `xtime(b) ⊕ b`. Em hardware, o MixColumns usa apenas deslocamentos e XORs, sem multiplicadores inteiros.

### 1.4 Transformações da cifragem

**SubBytes.** Substitui cada byte do State pela S-box, que combina o inverso multiplicativo em GF(2⁸) com uma transformação afim. É a única etapa não linear e a principal fonte de confusão da cifra. Exemplo do padrão: `53 → ED`. Em hardware, são 16 S-boxes no State (mais 4 na expansão de chave), implementáveis como LUT/ROM ou lógica combinacional.

**ShiftRows.** Rotaciona ciclicamente à esquerda a linha *i* em *i* bytes (0, 1, 2 e 3). Não altera os valores, apenas as posições, promovendo difusão entre colunas. Em hardware é só reconexão de fios, com custo praticamente nulo.

**MixColumns.** Multiplica cada coluna, independentemente, pela matriz fixa abaixo em GF(2⁸), promovendo difusão dentro da coluna:

```
| 02 03 01 01 |
| 01 02 03 01 |
| 01 01 02 03 |
| 03 01 01 02 |
```

Os coeficientes são hexadecimais e **não** correspondem a uma multiplicação matricial com inteiros convencionais.

**AddRoundKey.** XOR byte a byte entre o State e a Round Key. É a única etapa que depende da chave.

### 1.5 Estrutura da cifragem

| Etapa | Operações |
| :--- | :--- |
| Adição inicial da chave | AddRoundKey (Round Key 0) |
| Rodadas 1 a Nr − 1 | SubBytes → ShiftRows → MixColumns → AddRoundKey |
| Rodada final (Nr) | SubBytes → ShiftRows → AddRoundKey (**sem MixColumns**) |

No AES-128 são 9 rodadas completas e uma décima rodada sem MixColumns.

### 1.6 Expansão de chave (Key Expansion)

A chave original é expandida em **4 × (Nr + 1)** words, agrupadas de quatro em quatro para formar as Round Keys de 128 bits.

| Variante | Nk | Words geradas | Round Keys |
| :--- | :---: | :---: | :---: |
| AES-128 | 4 | 44 | 11 |
| AES-192 | 6 | 52 | 13 |
| AES-256 | 8 | 60 | 15 |

Operações auxiliares:

- **RotWord:** rotação cíclica dos bytes de uma word (`[a0,a1,a2,a3] → [a1,a2,a3,a0]`);
- **SubWord:** aplicação da S-box a cada um dos 4 bytes;
- **Rcon:** constante de rodada `[x^(i−1), 0, 0, 0]`, com valores `01, 02, 04, 08, 10, 20, 40, 80, 1B, 36` nas dez primeiras rodadas.

Para `i ≥ Nk`, com `w[i] = w[i−Nk] ⊕ temp`:

- se `i mod Nk = 0`: `temp = SubWord(RotWord(w[i−1])) ⊕ Rcon[i/Nk]`;
- se `Nk > 6` e `i mod Nk = 4` (AES-256): `temp = SubWord(w[i−1])`;
- caso contrário: `temp = w[i−1]`.

### 1.7 Decifragem

Usa as transformações inversas e as Round Keys em ordem reversa:

1. AddRoundKey com a última Round Key;
2. rodadas Nr − 1 até 1: **InvShiftRows → InvSubBytes → AddRoundKey → InvMixColumns**;
3. rodada final: InvShiftRows → InvSubBytes → AddRoundKey com a Round Key 0 (sem InvMixColumns).

- **InvSubBytes:** S-box inversa aplicada a cada byte.
- **InvShiftRows:** rotação à direita nas linhas, em 0, 1, 2 e 3 bytes.
- **InvMixColumns:** multiplicação de cada coluna pela matriz inversa abaixo, em GF(2⁸).

```
| 0E 0B 0D 09 |
| 09 0E 0B 0D |
| 0D 09 0E 0B |
| 0B 0D 09 0E |
```

AddRoundKey é sua própria inversa (XOR). A decifragem não é a cifragem executada ao contrário: usa operações inversas e a sequência de chaves invertida. Se o IP implementará só cifragem ou também decifragem depende da especificação funcional.

### 1.8 Implicações para a microarquitetura

O núcleo divide-se em **datapath** (registrador de State, SubBytes, ShiftRows, MixColumns, AddRoundKey e expansão de chave) e **controle** (contador de rodadas, seleção das transformações, sinalização de início e fim).

- **Iterativa (uma rodada por ciclo):** menor área e maior latência; candidata natural para um acelerador de baixo consumo.
- **Desenrolada ou pipeline:** maior vazão, com mais área e potência.

Pontos de atenção do RTL: implementação da S-box (LUT versus lógica), MixColumns em GF(2⁸), geração e armazenamento das Round Keys (*on-the-fly* ou pré-calculadas), ordenação dos bytes no State, ausência de MixColumns na última rodada e número de rodadas conforme a variante.

---

## 2. SPI — Serial Peripheral Interface

### 2.1 Visão geral

O SPI é uma interface serial **síncrona**, **full-duplex** e do tipo **mestre/escravo**. O mestre gera o clock serial e seleciona o escravo. Neste projeto, o SPI é usado para configurar e controlar o sistema (registradores de configuração, controle e status, incluindo configuração do PLL, além de dados e resultados), e o nosso bloco atua como **escravo**.

**Vantagens:** alta velocidade (dezenas de MHz), full-duplex, hardware simples, sem endereçamento no pacote e com quadros de tamanho flexível (8, 12, 16 bits ou mais).
**Desvantagens:** consumo de pinos (3 + N para N escravos) e ausência de confirmação de recebimento (ACK/NACK) no protocolo base.

### 2.2 Sinais

| Sinal | Direção | Função |
| :--- | :--- | :--- |
| **SCLK** | mestre → escravo | Clock serial, gerado pelo mestre. |
| **CS_N** | mestre → escravo | Chip select ativo em nível baixo; delimita a transação. |
| **MOSI** | mestre → escravo | Dados do mestre para o escravo. |
| **MISO** | escravo → mestre | Dados do escravo para o mestre. |

SCLK, MOSI e MISO são compartilhados entre os dispositivos; cada escravo tem seu próprio CS. A cada pulso de SCLK, um bit sai e outro entra simultaneamente. O enquadramento é feito pelo CS_N. A transmissão é normalmente **MSB-first**, embora algumas controladoras permitam LSB-first.

### 2.3 Modos de operação (CPOL e CPHA)

- **CPOL** (*clock polarity*): nível de repouso do SCLK (0 = baixo, 1 = alto).
- **CPHA** (*clock phase*): define se a amostragem ocorre na primeira ou na segunda borda do SCLK; o deslocamento (*shift*) ocorre na borda oposta.

| Modo | CPOL | CPHA | Repouso do SCLK | Amostragem |
| :---: | :---: | :---: | :---: | :--- |
| 0 | 0 | 0 | baixo | borda de subida |
| 1 | 0 | 1 | baixo | borda de descida |
| 2 | 1 | 0 | alto | borda de descida |
| 3 | 1 | 1 | alto | borda de subida |

Mestre e escravo precisam usar o mesmo modo. O modo adotado pelo projeto será definido pela especificação funcional.

### 2.4 Fluxo típico de uma transação

1. O mestre baixa CS_N.
2. O mestre envia pela MOSI um cabeçalho (por exemplo, bit de leitura/escrita e endereço do registrador) seguido dos dados; o formato exato depende da especificação.
3. O escravo desloca os bits recebidos para um registrador de deslocamento no ritmo do SCLK e devolve pela MISO o conteúdo lido.
4. O mestre sobe CS_N e encerra a transação.

### 2.5 Considerações para RTL

A recepção SPI deve detectar uma transferência válida (CS_N), receber os bits pela MOSI, agrupá-los, interpretar comandos e dados e repassá-los à lógica interna. No sentido contrário, os dados internos a enviar são serializados pela MISO.

---

## 3. Integração: SPI, registradores, AES e CDC

Fluxo conceitual de uma operação:

```
SPI Master → SPI Slave → Sincronização/CDC → Banco de Registradores
          → (start + key + plaintext) → AES Core
          → (ciphertext + status) → Banco de Registradores → SPI Slave → SPI Master
```

O **banco de registradores** faz a interface entre os comandos SPI e o núcleo AES (dados de entrada, chave, controle, status e resultado). O **núcleo AES** executa o processamento criptográfico, e a lógica ao redor controla o início da operação e identifica a conclusão.

### 3.1 Domínios de clock (principal risco técnico)

O sistema possui ao menos dois domínios:

- **domínio do SCLK:** registrador de deslocamento, contador de bits e saída MISO;
- **domínio do sistema:** banco de registradores, núcleo AES e interface de memória, no clock gerado pelo PLL.

Consequências a tratar:

- sinais de 1 bit que cruzam domínios precisam de **sincronizadores** (por exemplo, dois flip-flops) contra metaestabilidade;
- **barramentos multibit** não podem ser sincronizados bit a bit; exigem um protocolo de transferência coerente (handshake ou FIFO), senão ocorrem capturas inconsistentes de bits de ciclos diferentes;
- o PLL sai do reset com configuração padrão e trava sozinho (`locked`); seus registradores só devem ser reprogramados pelo SPI após o `locked`;
- a estratégia de reset de cada domínio precisa ser definida.

Esse ponto deve ser desenhado explicitamente antes de escrever o RTL do SPI.

---

## 4. Conclusões

- O AES é bem estruturado para hardware. A principal decisão de arquitetura é a microarquitetura (iterativa versus pipeline), que impacta diretamente área, timing e potência, o foco do projeto.
- O SPI é simples no fluxo de bits, mas sua integração ao sistema introduz o problema de CDC, o maior risco técnico, que exige solução arquitetural.
- Permanecem em aberto, dependendo da especificação funcional do instrutor: variante de AES suportada, escopo (cifragem e/ou decifragem), modo SPI e formato dos comandos, mapa de registradores e estratégia de reset e CDC.

---

