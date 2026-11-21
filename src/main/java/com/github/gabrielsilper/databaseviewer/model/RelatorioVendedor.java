package com.github.gabrielsilper.databaseviewer.model;

import java.util.List;

public record RelatorioVendedor(
        ResumoVendedor resumo,
        List<Comissao> comissoes
) {
}
