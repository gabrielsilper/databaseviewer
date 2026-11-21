package com.github.gabrielsilper.databaseviewer.controller;

import com.github.gabrielsilper.databaseviewer.form.VendaForm;
import com.github.gabrielsilper.databaseviewer.infra.ConnectionContext;
import com.github.gabrielsilper.databaseviewer.infra.ConnectionSession;
import com.github.gabrielsilper.databaseviewer.infra.SqlErrorMessage;
import com.github.gabrielsilper.databaseviewer.service.VendaService;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@Controller
public class VendaController {

    private final ConnectionSession connectionSession;
    private final VendaService vendaService;

    public VendaController(
            ConnectionSession connectionSession,
            VendaService vendaService
    ) {
        this.connectionSession = connectionSession;
        this.vendaService = vendaService;
    }

    @GetMapping("/venda")
    public String showForm(HttpSession session, Model model) {
        ConnectionContext connection = connectionSession.require(session);
        return render(connection, new VendaForm(), model);
    }

    @PostMapping("/venda")
    public String registra(
            @ModelAttribute("vendaForm") VendaForm form,
            HttpSession session,
            Model model,
            RedirectAttributes redirectAttributes
    ) {
        ConnectionContext connection = connectionSession.require(session);

        try {
            vendaService.registra(connection, form);

            redirectAttributes.addFlashAttribute(
                    "successMessage",
                    "Venda " + form.getVencodigo() + " registrada."
            );
            return "redirect:/venda";
        } catch (RuntimeException exception) {
            model.addAttribute(
                    "errorMessage",
                    "Venda não registrada: " + SqlErrorMessage.from(exception)
            );
            return render(connection, form, model);
        }
    }

    private String render(ConnectionContext connection, VendaForm form, Model model) {
        model.addAttribute("vendaForm", form);

        try {
            model.addAttribute("opcoes", vendaService.carregaOpcoes(connection));
        } catch (RuntimeException exception) {
            model.addAttribute("errorMessage", SqlErrorMessage.from(exception));
        }

        return "venda";
    }
}
