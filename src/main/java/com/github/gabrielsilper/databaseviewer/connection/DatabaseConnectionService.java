package com.github.gabrielsilper.databaseviewer.connection;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class DatabaseConnectionService {

    private final ConnectionRegistry registry;

    public DatabaseConnectionService(ConnectionRegistry registry) {
        this.registry = registry;
    }

    public UUID connect(ConnectionForm form) {
        validate(form);

        HikariConfig config = new HikariConfig();
        String urlConnection = getUrlConnection(form);
        config.setJdbcUrl(urlConnection);
        config.setUsername(form.getUsername());
        config.setPassword(form.getPassword());
        config.setMaximumPoolSize(2);
        config.setPoolName("database-viewer-" + UUID.randomUUID());

        HikariDataSource dataSource = new HikariDataSource(config);

        try {
            JdbcTemplate jdbcTemplate = new JdbcTemplate(dataSource);

            // Abre a conexão e confirma que as credenciais e o banco funcionam.
            jdbcTemplate.queryForObject("SELECT 1", Integer.class);

            return registry.register(
                    new ConnectionContext(dataSource, jdbcTemplate)
            );
        } catch (RuntimeException exception) {
            // Se a validação falhar, não deixe um pool aberto na memória.
            dataSource.close();
            throw exception;
        }
    }

    public ConnectionContext get(UUID id) {
        ConnectionContext context = registry.get(id);

        if (context == null) {
            throw new IllegalArgumentException("Conexão não encontrada");
        }

        return context;
    }

    public void close(UUID id) {
        registry.close(id);
    }

    private void validate(ConnectionForm form) {
        if (isBlank(form.getHost())) {
            throw new IllegalArgumentException("Host é obrigatório");
        }
        if (form.getPort() < 1 || form.getPort() > 65535) {
            throw new IllegalArgumentException("Porta deve estar entre 1 e 65535");
        }
        if (isBlank(form.getDatabase())) {
            throw new IllegalArgumentException("Banco é obrigatório");
        }
        if (isBlank(form.getUsername())) {
            throw new IllegalArgumentException("Usuário é obrigatório");
        }
        if (form.getPassword() == null) {
            throw new IllegalArgumentException("Senha é obrigatória");
        }
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private String getUrlConnection(ConnectionForm form) {
        return "jdbc:mysql://%s:%d/%s"
                .formatted(form.getHost(), form.getPort(), form.getDatabase());
    }
}
