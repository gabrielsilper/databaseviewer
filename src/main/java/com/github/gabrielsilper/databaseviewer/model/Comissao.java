package com.github.gabrielsilper.databaseviewer.model;

import java.math.BigDecimal;

public record Comissao(
        int ano,
        int mes,
        BigDecimal valor
) {
}
