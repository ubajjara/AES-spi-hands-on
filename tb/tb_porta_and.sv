`timescale 1ns/1ps

module tb_porta_and;

    // Sinais do testbench
    logic a;
    logic b;
    logic y;

    int erros = 0;

    // Instanciação do DUT (Device Under Test)
    porta_and dut (
        .a(a),
        .b(b),
        .y(y)
    );

    // Geração do dump FSDB
    initial begin
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_porta_and);
    end

    // Estímulos + verificação
    initial begin
        $display("----- Tabela-verdade da porta AND -----");

        for (int i = 0; i < 4; i++) begin
            {a, b} = i[1:0];
            #10;

            if (y !== (a & b)) begin
                $error("ERRO: a=%b b=%b y=%b (esperado %b)", a, b, y, a & b);
                erros++;
            end else begin
                $display("OK:   a=%b b=%b y=%b", a, b, y);
            end
        end

        $display("---------------------------------------");
        if (erros == 0)
            $display("TESTE PASSOU: 4/4 combinacoes corretas");
        else
            $display("TESTE FALHOU: %0d erro(s)", erros);

        $finish;
    end

endmodule