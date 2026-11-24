package com.github.gabrielsilper.databaseviewer.repository;

import com.github.gabrielsilper.databaseviewer.model.Opcao;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class CadastroRepository {

    private static final RowMapper<Opcao> OPCAO = (rs, rowNum) -> new Opcao(
            rs.getInt("codigo"),
            rs.getString("nome")
    );

    public List<Opcao> listaFiliais(JdbcTemplate jdbc) {
        return jdbc.query("CALL sp_lista_filiais_gabriel()", OPCAO);
    }

    public List<Opcao> listaClientesAtivos(JdbcTemplate jdbc) {
        return jdbc.query("CALL sp_lista_clientes_ativos_gabriel()", OPCAO);
    }

    public List<Opcao> listaFormasPagamentoAtivas(JdbcTemplate jdbc) {
        return jdbc.query("CALL sp_lista_formas_pagamento_ativas_gabriel()", OPCAO);
    }
}
