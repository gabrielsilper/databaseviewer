package com.github.gabrielsilper.databaseviewer.viewer;

import com.github.gabrielsilper.databaseviewer.connection.ConnectionContext;
import com.github.gabrielsilper.databaseviewer.connection.DatabaseConnectionService;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
public class DatabaseViewerService {

    private final DatabaseConnectionService connectionService;

    public DatabaseViewerService(DatabaseConnectionService connectionService) {
        this.connectionService = connectionService;
    }

    public List<String> findDatabases(UUID connectionId) {
        ConnectionContext context = connectionService.get(connectionId);
        JdbcTemplate jdbcTemplate = context.jdbcTemplate();

        String sql = "CALL sp_lista_nomes_bancos();";

        return jdbcTemplate.queryForList(sql, String.class);
    }

    public List<String> findTables(UUID connectionId, String database) {
        ConnectionContext context = connectionService.get(connectionId);
        JdbcTemplate jdbcTemplate = context.jdbcTemplate();

        String sql = "CALL sp_lista_nomes_tabelas(?);";

        return jdbcTemplate.queryForList(sql, String.class, database);
    }

    public List<ColumnInfo> findColumns(UUID connectionId, String database, String table) {
        ConnectionContext context = connectionService.get(connectionId);
        JdbcTemplate jdbcTemplate = context.jdbcTemplate();

        String sql = "CALL sp_lista_nomes_colunas(?, ?);";

        return jdbcTemplate.query(
                sql,
                (resultSet, rowNum) -> new ColumnInfo(
                        resultSet.getString("nome_coluna"),
                        resultSet.getString("tipo_coluna"),
                        resultSet.getString("is_nula")
                ),
                database,
                table
        );
    }
}
