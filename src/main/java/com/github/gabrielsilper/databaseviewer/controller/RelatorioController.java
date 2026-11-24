package com.github.gabrielsilper.databaseviewer.controller;

import com.github.gabrielsilper.databaseviewer.infra.ConnectionContext;
import com.github.gabrielsilper.databaseviewer.infra.ConnectionSession;
import com.github.gabrielsilper.databaseviewer.infra.SqlErrorMessage;
import com.github.gabrielsilper.databaseviewer.service.RelatorioService;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.time.LocalDate;

@Controller
public class RelatorioController {

    private final ConnectionSession connectionSession;
    private final RelatorioService relatorioService;

    public RelatorioController(
            ConnectionSession connectionSession,
            RelatorioService relatorioService
    ) {
        this.connectionSession = connectionSession;
        this.relatorioService = relatorioService;
    }

    /** /relatorio?vendedor=9&ano=2024&mes=1 (ano e mês padrão: mês atual) */
    @GetMapping("/relatorio")
    public String show(
            @RequestParam(required = false) Integer vendedor,
            @RequestParam(required = false) Integer ano,
            @RequestParam(required = false) Integer mes,
            HttpSession session,
            Model model
    ) {
        ConnectionContext connection = connectionSession.require(session);

        LocalDate hoje = LocalDate.now();
        int anoSelecionado = ano == null ? hoje.getYear() : ano;
        int mesSelecionado = mes == null ? hoje.getMonthValue() : mes;

        model.addAttribute("vendedorSelecionado", vendedor);
        model.addAttribute("ano", anoSelecionado);
        model.addAttribute("mes", mesSelecionado);

        try {
            model.addAttribute("vendedores", relatorioService.listaVendedores(connection));

            if (vendedor != null) {
                model.addAttribute("comissoes", relatorioService.listaRelatorios(connection, vendedor));
            }
        } catch (RuntimeException exception) {
            model.addAttribute("errorMessage", SqlErrorMessage.from(exception));
        }

        return "relatorio";
    }

    @PostMapping("/relatorio/gerar")
    public String gera(
            @RequestParam int vendedor,
            @RequestParam int ano,
            @RequestParam int mes,
            HttpSession session,
            RedirectAttributes redirectAttributes
    ) {
        ConnectionContext connection = connectionSession.require(session);

        try {
            relatorioService.geraRelatorio(connection, vendedor, ano, mes);
            redirectAttributes.addFlashAttribute(
                    "successMessage",
                    String.format("Relatório de %02d/%d gerado.", mes, ano)
            );
        } catch (RuntimeException exception) {
            redirectAttributes.addFlashAttribute(
                    "errorMessage",
                    "Relatório não gerado: " + SqlErrorMessage.from(exception)
            );
        }

        redirectAttributes.addAttribute("vendedor", vendedor);
        redirectAttributes.addAttribute("ano", ano);
        redirectAttributes.addAttribute("mes", mes);
        return "redirect:/relatorio";
    }
}
