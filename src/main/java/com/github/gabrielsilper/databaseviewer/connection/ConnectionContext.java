package com.github.gabrielsilper.databaseviewer.connection;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.jdbc.core.JdbcTemplate;

public record ConnectionContext(
        HikariDataSource dataSource,
        JdbcTemplate jdbcTemplate
) implements AutoCloseable {
    @Override
    public void close() {
        dataSource.close();
    }
}
