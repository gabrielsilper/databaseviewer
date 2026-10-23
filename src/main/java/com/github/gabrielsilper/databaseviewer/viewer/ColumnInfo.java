package com.github.gabrielsilper.databaseviewer.viewer;

public record ColumnInfo(
        String name,
        String type,
        String nullable
) {
}
