package com.github.gabrielsilper.databaseviewer.repository;

import com.github.gabrielsilper.databaseviewer.model.ColumnInfo;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * Acesso aos metadados do banco. Só chama as procedures e mapeia o resultado.
 * O JdbcTemplate vem de quem chama (a conexão é de cada usuário).
 */
@Repository
public class ViewerRepository {

    public List<String> findDatabases(JdbcTemplate jdbc) {
        return jdbc.queryForList("CALL sp_lista_nomes_bancos_gabriel()", String.class);
    }

    public List<String> findTables(JdbcTemplate jdbc, String database) {
        return jdbc.queryForList("CALL sp_lista_nomes_tabelas_gabriel(?)", String.class, database);
    }

    public List<ColumnInfo> findColumns(JdbcTemplate jdbc, String database, String table) {
        return jdbc.query(
                "CALL sp_lista_nomes_colunas_gabriel(?, ?)",
                (resultSet, rowNum) -> new ColumnInfo(
                        resultSet.getString("nome_coluna"),
                        resultSet.getString("tipo_coluna"),
                        resultSet.getString("is_nula")
                ),
                database,
                table
        );
    }

    /** Tabelas que esta tabela referencia (ela é o lado N, elas o lado 1). */
    public List<String> findOneSideTables(JdbcTemplate jdbc, String database, String table) {
        return jdbc.queryForList(
                "CALL sp_lista_nomes_tabelas_lado_1_gabriel(?, ?)",
                String.class,
                database,
                table
        );
    }

    /** Tabelas que referenciam esta tabela (ela é o lado 1, elas o lado N). */
    public List<String> findManySideTables(JdbcTemplate jdbc, String database, String table) {
        return jdbc.queryForList(
                "CALL sp_lista_nomes_tabelas_lado_n_gabriel(?, ?)",
                String.class,
                database,
                table
        );
    }
}
