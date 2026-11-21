package com.github.gabrielsilper.databaseviewer.repository;

import com.github.gabrielsilper.databaseviewer.form.VendaForm;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class VendaRepository {

    public void registraVenda(JdbcTemplate jdbc, VendaForm venda) {
        jdbc.update(
                "CALL sp_tx_registra_venda(?, ?, ?, ?, ?, ?, ?)",
                venda.getVencodigo(),
                venda.getFilcodigo(),
                venda.getClicodigo(),
                venda.getFuncodigo(),
                venda.getFpcodigo(),
                venda.getProcodigo(),
                venda.getQtde()
        );
    }
}
