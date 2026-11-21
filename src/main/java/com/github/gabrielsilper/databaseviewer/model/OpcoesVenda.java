package com.github.gabrielsilper.databaseviewer.model;

import java.util.List;

public record OpcoesVenda(
        List<Opcao> filiais,
        List<Opcao> clientes,
        List<Vendedor> vendedores,
        List<Opcao> formasPagamento,
        List<Produto> produtos
) {
}
