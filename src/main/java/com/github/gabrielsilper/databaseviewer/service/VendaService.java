package com.github.gabrielsilper.databaseviewer.service;

import com.github.gabrielsilper.databaseviewer.form.VendaForm;
import com.github.gabrielsilper.databaseviewer.infra.ConnectionContext;
import com.github.gabrielsilper.databaseviewer.model.OpcoesVenda;
import com.github.gabrielsilper.databaseviewer.model.Vendedor;
import com.github.gabrielsilper.databaseviewer.repository.CadastroRepository;
import com.github.gabrielsilper.databaseviewer.repository.ProdutoRepository;
import com.github.gabrielsilper.databaseviewer.repository.VendaRepository;
import com.github.gabrielsilper.databaseviewer.repository.VendedorRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.stream.Stream;

@Service
public class VendaService {

    private final CadastroRepository cadastroRepository;
    private final VendedorRepository vendedorRepository;
    private final ProdutoRepository produtoRepository;
    private final VendaRepository vendaRepository;

    public VendaService(
            CadastroRepository cadastroRepository,
            VendedorRepository vendedorRepository,
            ProdutoRepository produtoRepository,
            VendaRepository vendaRepository
    ) {
        this.cadastroRepository = cadastroRepository;
        this.vendedorRepository = vendedorRepository;
        this.produtoRepository = produtoRepository;
        this.vendaRepository = vendaRepository;
    }

    public OpcoesVenda carregaOpcoes(ConnectionContext connection) {
        JdbcTemplate jdbc = connection.jdbcTemplate();

        return new OpcoesVenda(
                cadastroRepository.listaFiliais(jdbc),
                cadastroRepository.listaClientesAtivos(jdbc),
                vendedorRepository.listaVendedores(jdbc).stream()
                        .filter(Vendedor::ativo)
                        .toList(),
                cadastroRepository.listaFormasPagamentoAtivas(jdbc),
                produtoRepository.listaProdutosAtivos(jdbc)
        );
    }

    public void registra(ConnectionContext connection, VendaForm venda) {
        boolean faltaCampo = Stream.of(
                venda.getVencodigo(), venda.getFilcodigo(), venda.getClicodigo(),
                venda.getFuncodigo(), venda.getFpcodigo(), venda.getProcodigo(),
                venda.getQtde()
        ).anyMatch(campo -> campo == null);

        if (faltaCampo) {
            throw new IllegalArgumentException("Preencha todos os campos da venda.");
        }

        vendaRepository.registraVenda(connection.jdbcTemplate(), venda);
    }
}
