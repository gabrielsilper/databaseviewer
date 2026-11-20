package com.github.gabrielsilper.databaseviewer.infra;

import org.springframework.dao.DataAccessException;

import java.sql.SQLException;

/**
 * Transforma uma exceção (normalmente vinda do banco) em uma mensagem para a tela.
 */
public final class SqlErrorMessage {

    private static final String SIGNAL_SQLSTATE = "45000";
    private static final int DUPLICATE_KEY = 1062;
    private static final int DEADLOCK = 1213;

    private SqlErrorMessage() {
    }

    public static String from(RuntimeException exception) {
        Throwable cause = exception instanceof DataAccessException dataAccess
                ? dataAccess.getMostSpecificCause()
                : exception;

        if (cause instanceof SQLException sql) {
            // erro lançado por "signal sqlstate '45000'" nas procedures
            if (SIGNAL_SQLSTATE.equals(sql.getSQLState())) {
                return sql.getMessage();
            }
            if (sql.getErrorCode() == DUPLICATE_KEY) {
                return "Já existe um registro com essa chave.";
            }
            if (sql.getErrorCode() == DEADLOCK) {
                return "Conflito com outra transação (deadlock). Tente novamente.";
            }
        }

        String message = cause.getMessage();

        if (message == null || message.isBlank()) {
            return "verifique os dados informados e tente novamente";
        }

        return message;
    }
}
