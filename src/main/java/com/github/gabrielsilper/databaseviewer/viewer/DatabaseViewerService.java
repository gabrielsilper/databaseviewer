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

    public RelationshipInfo findRelationships(
            UUID connectionId,
            String database,
            String table
    ) {
        ConnectionContext context = connectionService.get(connectionId);
        JdbcTemplate jdbcTemplate = context.jdbcTemplate();

        // TODO: informe aqui o SQL dos relacionamentos do lado 1.
        String sqlOneSide = "";

        // TODO: informe aqui o SQL dos relacionamentos do lado N.
        String sqlManySide = "";

        if (sqlOneSide.isBlank() || sqlManySide.isBlank()) {
            return RelationshipInfo.empty();
        }

        List<String> oneSide = jdbcTemplate.queryForList(
                sqlOneSide,
                String.class,
                database,
                table
        );
        List<String> manySide = jdbcTemplate.queryForList(
                sqlManySide,
                String.class,
                database,
                table
        );

        return new RelationshipInfo(
                oneSide == null ? List.of() : oneSide,
                manySide == null ? List.of() : manySide
        );
    }
}
