package com.github.gabrielsilper.databaseviewer.model;

import java.util.List;

public record RelationshipInfo(
        List<String> oneSide,
        List<String> manySide
) {

    public static RelationshipInfo empty() {
        return new RelationshipInfo(List.of(), List.of());
    }
}
