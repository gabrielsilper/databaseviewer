package com.github.gabrielsilper.databaseviewer.connection;

import jakarta.servlet.http.HttpSessionBindingEvent;
import jakarta.servlet.http.HttpSessionBindingListener;

import java.util.UUID;

public class ConnectionSessionBinding implements HttpSessionBindingListener {

    private final ConnectionRegistry registry;
    private final UUID connectionId;

    public ConnectionSessionBinding(
            ConnectionRegistry registry,
            UUID connectionId
    ) {
        this.registry = registry;
        this.connectionId = connectionId;
    }

    @Override
    public void valueUnbound(HttpSessionBindingEvent event) {
        registry.close(connectionId);
    }
}
