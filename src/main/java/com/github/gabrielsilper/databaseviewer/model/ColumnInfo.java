package com.github.gabrielsilper.databaseviewer.model;

public record ColumnInfo(
        String name,
        String type,
        String nullable
) {
}
