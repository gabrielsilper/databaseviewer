package com.github.gabrielsilper.databaseviewer.infra;

import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Component;

import java.util.UUID;

/**
 * Único lugar que sabe como a conexão do usuário fica guardada na sessão HTTP.
 * A sessão guarda só o UUID; o pool de conexões fica no ConnectionRegistry.
 */
@Component
public class ConnectionSession {

    private static final String CONNECTION_ID = "databaseConnectionId";
    private static final String CONNECTION_BINDING = "databaseConnectionBinding";

    private final ConnectionRegistry registry;

    public ConnectionSession(ConnectionRegistry registry) {
        this.registry = registry;
    }

    /** Associa uma conexão nova à sessão, fechando a anterior (se houver). */
    public void open(HttpSession session, UUID connectionId) {
        close(session);

        session.setAttribute(CONNECTION_ID, connectionId.toString());
        // Quando este atributo sai da sessão (ou a sessão expira), o pool é fechado.
        session.setAttribute(
                CONNECTION_BINDING,
                new ConnectionSessionBinding(registry, connectionId)
        );
    }

    /** Remove a conexão da sessão; o ConnectionSessionBinding fecha o pool. */
    public void close(HttpSession session) {
        session.removeAttribute(CONNECTION_BINDING);
        session.removeAttribute(CONNECTION_ID);
    }

    /** Devolve a conexão da sessão ou lança NoConnectionException. */
    public ConnectionContext require(HttpSession session) {
        Object connectionId = session.getAttribute(CONNECTION_ID);

        if (connectionId == null) {
            throw new NoConnectionException();
        }

        ConnectionContext context = registry.get(UUID.fromString(connectionId.toString()));

        if (context == null) {
            throw new NoConnectionException();
        }

        return context;
    }
}
