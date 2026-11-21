package com.github.gabrielsilper.databaseviewer.model;

import java.math.BigDecimal;

public record Produto(
        int codigo,
        String nome,
        BigDecimal preco,
        int saldo,
        boolean ativo
) {
}
