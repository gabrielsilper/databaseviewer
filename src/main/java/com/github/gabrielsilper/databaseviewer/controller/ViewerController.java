package com.github.gabrielsilper.databaseviewer.controller;

import com.github.gabrielsilper.databaseviewer.infra.ConnectionContext;
import com.github.gabrielsilper.databaseviewer.infra.ConnectionSession;
import com.github.gabrielsilper.databaseviewer.infra.SqlErrorMessage;
import com.github.gabrielsilper.databaseviewer.model.ViewerPage;
import com.github.gabrielsilper.databaseviewer.service.ViewerService;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@Controller
public class ViewerController {

    private final ConnectionSession connectionSession;
    private final ViewerService viewerService;

    public ViewerController(
            ConnectionSession connectionSession,
            ViewerService viewerService
    ) {
        this.connectionSession = connectionSession;
        this.viewerService = viewerService;
    }

    @GetMapping("/viewer")
    public String showViewer(
            @RequestParam(defaultValue = "") String database,
            @RequestParam(defaultValue = "") String table,
            HttpSession session,
            Model model,
            RedirectAttributes redirectAttributes
    ) {
        ConnectionContext connection = connectionSession.require(session);

        try {
            ViewerPage page = viewerService.load(connection, database.trim(), table.trim());

            model.addAttribute("databases", page.databases());
            model.addAttribute("selectedDatabase", page.selectedDatabase());
            model.addAttribute("tables", page.tables());
            model.addAttribute("selectedTable", page.selectedTable());
            model.addAttribute("columns", page.columns());
            model.addAttribute("relationships", page.relationships());

            return "viewer";
        } catch (RuntimeException exception) {
            redirectAttributes.addFlashAttribute(
                    "errorMessage",
                    "Não foi possível carregar os bancos: " + SqlErrorMessage.from(exception)
            );
            return "redirect:/connect";
        }
    }
}
