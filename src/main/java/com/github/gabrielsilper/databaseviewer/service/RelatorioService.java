package com.github.gabrielsilper.databaseviewer.service;

import com.github.gabrielsilper.databaseviewer.infra.ConnectionContext;
import com.github.gabrielsilper.databaseviewer.model.RelatorioVendedor;
import com.github.gabrielsilper.databaseviewer.model.Vendedor;
import com.github.gabrielsilper.databaseviewer.repository.VendedorRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class RelatorioService {

    private final VendedorRepository vendedorRepository;

    public RelatorioService(VendedorRepository vendedorRepository) {
        this.vendedorRepository = vendedorRepository;
    }

    public List<Vendedor> listaVendedores(ConnectionContext connection) {
        return vendedorRepository.listaVendedores(connection.jdbcTemplate());
    }

    public void geraRelatorio(ConnectionContext connection, int vendedor, int ano, int mes) {
        validaMes(mes);
        vendedorRepository.geraRelatorio(connection.jdbcTemplate(), vendedor, ano, mes);
    }

    public RelatorioVendedor consulta(ConnectionContext connection, int vendedor, int ano, int mes) {
        validaMes(mes);

        JdbcTemplate jdbc = connection.jdbcTemplate();

        return new RelatorioVendedor(
                vendedorRepository.totalVendas(jdbc, vendedor, ano, mes),
                vendedorRepository.listaComissoes(jdbc, vendedor)
        );
    }

    private void validaMes(int mes) {
        if (mes < 1 || mes > 12) {
            throw new IllegalArgumentException("Mês deve estar entre 1 e 12.");
        }
    }
}
