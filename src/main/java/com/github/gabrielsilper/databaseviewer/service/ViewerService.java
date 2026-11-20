package com.github.gabrielsilper.databaseviewer.service;

import com.github.gabrielsilper.databaseviewer.infra.ConnectionContext;
import com.github.gabrielsilper.databaseviewer.model.ColumnInfo;
import com.github.gabrielsilper.databaseviewer.model.RelationshipInfo;
import com.github.gabrielsilper.databaseviewer.model.ViewerPage;
import com.github.gabrielsilper.databaseviewer.repository.ViewerRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class ViewerService {

    private final ViewerRepository viewerRepository;

    public ViewerService(ViewerRepository viewerRepository) {
        this.viewerRepository = viewerRepository;
    }

    /**
     * Monta a tela do viewer: sempre lista os bancos; lista as tabelas se um
     * banco foi escolhido; campos e relacionamentos se uma tabela foi escolhida.
     */
    public ViewerPage load(ConnectionContext connection, String database, String table) {
        JdbcTemplate jdbc = connection.jdbcTemplate();

        List<String> databases = viewerRepository.findDatabases(jdbc);
        List<String> tables = List.of();
        List<ColumnInfo> columns = List.of();
        RelationshipInfo relationships = RelationshipInfo.empty();

        if (!database.isEmpty()) {
            tables = viewerRepository.findTables(jdbc, database);
        }

        if (!database.isEmpty() && !table.isEmpty()) {
            columns = viewerRepository.findColumns(jdbc, database, table);
            relationships = new RelationshipInfo(
                    viewerRepository.findOneSideTables(jdbc, database, table),
                    viewerRepository.findManySideTables(jdbc, database, table)
            );
        }

        return new ViewerPage(databases, database, tables, table, columns, relationships);
    }
}
