package com.github.gabrielsilper.databaseviewer.connection;

import org.springframework.stereotype.Component;

import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

@Component
public class ConnectionRegistry {

    private final ConcurrentMap<UUID, ConnectionContext> connections = new ConcurrentHashMap<>();

    public UUID register(ConnectionContext context) {
        UUID id = UUID.randomUUID();
        connections.put(id, context);
        return id;
    }

    public ConnectionContext get(UUID id) {
        return connections.get(id);
    }

    public ConnectionContext remove(UUID id) {
        return connections.remove(id);
    }

    public void close(UUID id) {
        ConnectionContext context = remove(id);
        if (context != null) {
            context.close();
        }
    }
}
