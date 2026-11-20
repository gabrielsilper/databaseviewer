package com.github.gabrielsilper.databaseviewer.controller;

import com.github.gabrielsilper.databaseviewer.form.ConnectionForm;
import com.github.gabrielsilper.databaseviewer.infra.ConnectionSession;
import com.github.gabrielsilper.databaseviewer.infra.SqlErrorMessage;
import com.github.gabrielsilper.databaseviewer.service.ConnectionService;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.util.UUID;

@Controller
public class ConnectController {

    private final ConnectionService connectionService;
    private final ConnectionSession connectionSession;

    public ConnectController(
            ConnectionService connectionService,
            ConnectionSession connectionSession
    ) {
        this.connectionService = connectionService;
        this.connectionSession = connectionSession;
    }

    @GetMapping("/")
    public String home() {
        return "redirect:/connect";
    }

    @GetMapping("/connect")
    public String showForm(Model model) {
        model.addAttribute("connectionForm", new ConnectionForm());
        return "connect";
    }

    @PostMapping("/connect")
    public String connect(
            @ModelAttribute("connectionForm") ConnectionForm form,
            HttpSession session,
            RedirectAttributes redirectAttributes
    ) {
        try {
            UUID connectionId = connectionService.connect(form);
            connectionSession.open(session, connectionId);
            return "redirect:/viewer";
        } catch (RuntimeException exception) {
            redirectAttributes.addFlashAttribute(
                    "errorMessage",
                    "Não foi possível conectar: " + SqlErrorMessage.from(exception)
            );
            return "redirect:/connect";
        }
    }
}
