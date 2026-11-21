package com.github.gabrielsilper.databaseviewer.service;

import com.github.gabrielsilper.databaseviewer.infra.ConnectionContext;
import com.github.gabrielsilper.databaseviewer.model.Produto;
import com.github.gabrielsilper.databaseviewer.model.Reajuste;
import com.github.gabrielsilper.databaseviewer.repository.ProdutoRepository;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

@Service
public class ProdutoService {

    private final ProdutoRepository produtoRepository;

    public ProdutoService(ProdutoRepository produtoRepository) {
        this.produtoRepository = produtoRepository;
    }

    public List<Produto> listaTodos(ConnectionContext connection) {
        return produtoRepository.listaProdutos(connection.jdbcTemplate());
    }

    public Optional<Produto> consulta(ConnectionContext connection, int codigo) {
        return produtoRepository.consultaProduto(connection.jdbcTemplate(), codigo);
    }

    public Reajuste reajusta(ConnectionContext connection, Integer codigo, BigDecimal percentual) {
        if (codigo == null || percentual == null) {
            throw new IllegalArgumentException("Informe o código do produto e o percentual.");
        }

        return produtoRepository.reajustaPreco(connection.jdbcTemplate(), codigo, percentual);
    }
}
