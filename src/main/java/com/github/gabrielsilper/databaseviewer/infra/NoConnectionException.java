package com.github.gabrielsilper.databaseviewer.infra;

/**
 * Lançada quando uma página precisa de conexão e a sessão não tem nenhuma.
 * Tratada no GlobalExceptionHandler (redireciona para a tela de conexão).
 */
public class NoConnectionException extends RuntimeException {

    public NoConnectionException() {
        super("Conecte-se a um banco antes de continuar.");
    }
}
