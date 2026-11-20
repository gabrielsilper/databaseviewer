package com.github.gabrielsilper.databaseviewer.controller;

import com.github.gabrielsilper.databaseviewer.infra.NoConnectionException;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.servlet.support.RequestContextUtils;

/**
 * Tratamento de erros comum a todos os controllers.
 */
@ControllerAdvice
public class GlobalExceptionHandler {

    /** Página que precisa de conexão foi aberta sem conexão: volta para /connect. */
    @ExceptionHandler(NoConnectionException.class)
    public String handleNoConnection(
            NoConnectionException exception,
            HttpServletRequest request
    ) {
        // equivalente ao addFlashAttribute do RedirectAttributes
        RequestContextUtils.getOutputFlashMap(request)
                .put("errorMessage", exception.getMessage());

        return "redirect:/connect";
    }
}
