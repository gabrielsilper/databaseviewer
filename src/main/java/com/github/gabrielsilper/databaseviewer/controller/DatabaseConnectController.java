package com.github.gabrielsilper.databaseviewer.controller;

import com.github.gabrielsilper.databaseviewer.connection.ConnectionForm;
import com.github.gabrielsilper.databaseviewer.connection.ConnectionRegistry;
import com.github.gabrielsilper.databaseviewer.connection.ConnectionSessionBinding;
import com.github.gabrielsilper.databaseviewer.connection.DatabaseConnectionService;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.util.UUID;

@Controller
@RequestMapping("/database/connect")
public class DatabaseConnectController {

    private static final String CONNECTION_ID = "databaseConnectionId";
    private static final String CONNECTION_BINDING = "databaseConnectionBinding";

    private final DatabaseConnectionService connectionService;
    private final ConnectionRegistry connectionRegistry;

    public DatabaseConnectController(
            DatabaseConnectionService connectionService,
            ConnectionRegistry connectionRegistry
    ) {
        this.connectionService = connectionService;
        this.connectionRegistry = connectionRegistry;
    }

    @GetMapping
    public String showForm(HttpSession session, Model model) {
        model.addAttribute("connectionForm", new ConnectionForm());
        model.addAttribute("connectionId", session.getAttribute(CONNECTION_ID));
        return "database/connect";
    }

    @PostMapping
    public String connect(
            @ModelAttribute("connectionForm") ConnectionForm form,
            HttpSession session,
            RedirectAttributes redirectAttributes
    ) {
        try {
            UUID connectionId = connectionService.connect(form);

            removePreviousConnection(session);

            session.setAttribute(CONNECTION_ID, connectionId.toString());
            session.setAttribute(
                    CONNECTION_BINDING,
                    new ConnectionSessionBinding(connectionRegistry, connectionId)
            );

            redirectAttributes.addFlashAttribute(
                    "successMessage",
                    "Conexão realizada com sucesso."
            );
        } catch (RuntimeException exception) {
            redirectAttributes.addFlashAttribute(
                    "errorMessage",
                    "Não foi possível conectar: " + readableMessage(exception)
            );
        }

        return "redirect:/database/connect";
    }

    private void removePreviousConnection(HttpSession session) {
        session.removeAttribute(CONNECTION_BINDING);
        session.removeAttribute(CONNECTION_ID);
    }

    private String readableMessage(RuntimeException exception) {
        if (exception.getMessage() == null || exception.getMessage().isBlank()) {
            return "verifique os dados informados e tente novamente";
        }
        return exception.getMessage();
    }
}