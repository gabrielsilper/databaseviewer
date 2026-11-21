package com.github.gabrielsilper.databaseviewer.controller;

import com.github.gabrielsilper.databaseviewer.infra.ConnectionContext;
import com.github.gabrielsilper.databaseviewer.infra.ConnectionSession;
import com.github.gabrielsilper.databaseviewer.infra.SqlErrorMessage;
import com.github.gabrielsilper.databaseviewer.model.Produto;
import com.github.gabrielsilper.databaseviewer.model.Reajuste;
import com.github.gabrielsilper.databaseviewer.service.ProdutoService;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.math.BigDecimal;
import java.util.List;
import java.util.Locale;

@Controller
public class ProdutoController {

    private static final Locale PT_BR = Locale.of("pt", "BR");

    private final ConnectionSession connectionSession;
    private final ProdutoService produtoService;

    public ProdutoController(
            ConnectionSession connectionSession,
            ProdutoService produtoService
    ) {
        this.connectionSession = connectionSession;
        this.produtoService = produtoService;
    }

    /**
     * Uma tabela só, filtrada pelos query params:
     * /produtos              -> tabela vazia (só os formulários)
     * /produtos?todos=true   -> todos os produtos
     * /produtos?codigo=21    -> só o produto 21
     */
    @GetMapping("/produtos")
    public String show(
            @RequestParam(defaultValue = "false") boolean todos,
            @RequestParam(required = false) Integer codigo,
            HttpSession session,
            Model model
    ) {
        ConnectionContext connection = connectionSession.require(session);

        List<Produto> produtos = List.of();
        model.addAttribute("codigo", codigo);

        try {
            if (todos) {
                produtos = produtoService.listaTodos(connection);
            } else if (codigo != null) {
                produtos = produtoService.consulta(connection, codigo).stream().toList();

                // não sobrescreve um erro que veio do reajuste (flash attribute)
                if (produtos.isEmpty() && !model.containsAttribute("errorMessage")) {
                    model.addAttribute("errorMessage", "Produto " + codigo + " não encontrado.");
                }
            }
        } catch (RuntimeException exception) {
            model.addAttribute("errorMessage", SqlErrorMessage.from(exception));
        }

        model.addAttribute("produtos", produtos);
        return "produtos";
    }

    @PostMapping("/produtos/reajuste")
    public String reajusta(
            @RequestParam(required = false) Integer codigo,
            @RequestParam(required = false) BigDecimal percentual,
            HttpSession session,
            RedirectAttributes redirectAttributes
    ) {
        ConnectionContext connection = connectionSession.require(session);

        try {
            Reajuste reajuste = produtoService.reajusta(connection, codigo, percentual);

            redirectAttributes.addFlashAttribute(
                    "successMessage",
                    String.format(
                            PT_BR,
                            "Preço de %s: R$ %,.2f → R$ %,.2f",
                            reajuste.nome(),
                            reajuste.precoAnterior(),
                            reajuste.precoNovo()
                    )
            );
        } catch (RuntimeException exception) {
            redirectAttributes.addFlashAttribute(
                    "errorMessage",
                    "Reajuste não realizado: " + SqlErrorMessage.from(exception)
            );
        }

        if (codigo != null) {
            redirectAttributes.addAttribute("codigo", codigo);
        }
        return "redirect:/produtos";
    }
}
