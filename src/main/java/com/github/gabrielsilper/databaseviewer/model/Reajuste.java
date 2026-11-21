package com.github.gabrielsilper.databaseviewer.model;

import java.math.BigDecimal;

public record Reajuste(
        int codigo,
        String nome,
        BigDecimal precoAnterior,
        BigDecimal precoNovo
) {
}
