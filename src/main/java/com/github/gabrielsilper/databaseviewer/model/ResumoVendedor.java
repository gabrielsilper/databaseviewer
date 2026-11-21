package com.github.gabrielsilper.databaseviewer.model;

import java.math.BigDecimal;

public record ResumoVendedor(
        int codigo,
        String nome,
        int qtdeVendas,
        BigDecimal comissao
) {
}
