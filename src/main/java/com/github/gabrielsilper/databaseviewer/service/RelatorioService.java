package com.github.gabrielsilper.databaseviewer.service;

import com.github.gabrielsilper.databaseviewer.infra.ConnectionContext;
import com.github.gabrielsilper.databaseviewer.model.Comissao;
import com.github.gabrielsilper.databaseviewer.model.Vendedor;
import com.github.gabrielsilper.databaseviewer.repository.VendedorRepository;
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

    public List<Comissao> listaRelatorios(ConnectionContext connection, int vendedor) {
        return vendedorRepository.listaComissoes(connection.jdbcTemplate(), vendedor);
    }

    private void validaMes(int mes) {
        if (mes < 1 || mes > 12) {
            throw new IllegalArgumentException("Mês deve estar entre 1 e 12.");
        }
    }
}
