package com.github.gabrielsilper.databaseviewer.model;

import java.util.List;

/**
 * Tudo o que a tela do viewer mostra, montado pelo ViewerService.
 * Listas vazias significam "nada selecionado" ou "nada encontrado".
 */
public record ViewerPage(
        List<String> databases,
        String selectedDatabase,
        List<String> tables,
        String selectedTable,
        List<ColumnInfo> columns,
        RelationshipInfo relationships
) {
}
