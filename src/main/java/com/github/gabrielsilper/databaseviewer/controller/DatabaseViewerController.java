package com.github.gabrielsilper.databaseviewer.controller;

import com.github.gabrielsilper.databaseviewer.viewer.DatabaseViewerService;
import com.github.gabrielsilper.databaseviewer.viewer.ColumnInfo;
import com.github.gabrielsilper.databaseviewer.viewer.RelationshipInfo;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.util.List;
import java.util.UUID;

@Controller
@RequestMapping("/database/viewer")
public class DatabaseViewerController {

    private static final String CONNECTION_ID = "databaseConnectionId";

    private final DatabaseViewerService viewerService;

    public DatabaseViewerController(DatabaseViewerService viewerService) {
        this.viewerService = viewerService;
    }

    @GetMapping
    public String showViewer(
            HttpSession session,
            Model model,
            RedirectAttributes redirectAttributes,
            @RequestParam(required = false) String database,
            @RequestParam(required = false) String table
    ) {
        Object connectionIdAttribute = session.getAttribute(CONNECTION_ID);

        if (connectionIdAttribute == null) {
            redirectAttributes.addFlashAttribute(
                    "errorMessage",
                    "Conecte-se a um banco antes de abrir o viewer."
            );
            return "redirect:/database/connect";
        }

        try {
            UUID connectionId = UUID.fromString(connectionIdAttribute.toString());
            List<String> loadedDatabases = viewerService.findDatabases(connectionId);
            List<String> databases = loadedDatabases == null
                    ? List.of()
                    : loadedDatabases;
            String selectedDatabase = database == null ? "" : database.trim();
            List<String> tables = List.of();

            model.addAttribute("databases", databases);
            model.addAttribute("selectedDatabase", selectedDatabase);

            if (!selectedDatabase.isEmpty()) {
                List<String> loadedTables = viewerService.findTables(
                        connectionId,
                        selectedDatabase
                );
                tables = loadedTables == null ? List.of() : loadedTables;
            }

            model.addAttribute("tables", tables);

            List<ColumnInfo> columns = List.of();

            String selectedTable = table == null ? "" : table.trim();
            model.addAttribute("selectedTable", selectedTable);

            if (!selectedDatabase.isEmpty() && !selectedTable.isEmpty()) {
                List<ColumnInfo> loadedColumns = viewerService.findColumns(
                        connectionId,
                        selectedDatabase,
                        selectedTable
                );

                columns = loadedColumns == null ? List.of() : loadedColumns;
            }

            model.addAttribute("columns", columns);

            RelationshipInfo relationships = RelationshipInfo.empty();

            if (!selectedDatabase.isEmpty() && !selectedTable.isEmpty()) {
                RelationshipInfo loadedRelationships = viewerService.findRelationships(
                        connectionId,
                        selectedDatabase,
                        selectedTable
                );

                if (loadedRelationships != null) {
                    relationships = loadedRelationships;
                }
            }

            model.addAttribute("relationships", relationships);

            return "database/viewer";
        } catch (RuntimeException exception) {
            redirectAttributes.addFlashAttribute(
                    "errorMessage",
                    "Não foi possível carregar os bancos: " + readableMessage(exception)
            );
            return "redirect:/database/connect";
        }
    }

    private String readableMessage(RuntimeException exception) {
        if (exception.getMessage() == null || exception.getMessage().isBlank()) {
            return "verifique a conexão e tente novamente";
        }
        return exception.getMessage();
    }
}
