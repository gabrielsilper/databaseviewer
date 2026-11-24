package com.github.gabrielsilper.databaseviewer.repository;

import com.github.gabrielsilper.databaseviewer.model.Produto;
import com.github.gabrielsilper.databaseviewer.model.Reajuste;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

@Repository
public class ProdutoRepository {

    private static final RowMapper<Produto> PRODUTO = (rs, rowNum) -> new Produto(
            rs.getInt("procodigo"),
            rs.getString("pronome"),
            rs.getBigDecimal("propreco"),
            rs.getInt("prosaldo"),
            "1".equals(rs.getString("proativo"))
    );

    public List<Produto> listaProdutos(JdbcTemplate jdbc) {
        return jdbc.query("CALL sp_lista_produtos_gabriel()", PRODUTO);
    }

    public List<Produto> listaProdutosAtivos(JdbcTemplate jdbc) {
        return jdbc.query("CALL sp_lista_produtos_ativos_gabriel()", PRODUTO);
    }

    public Optional<Produto> consultaProduto(JdbcTemplate jdbc, int codigo) {
        return jdbc.query("CALL sp_consulta_produto_gabriel(?)", PRODUTO, codigo)
                .stream()
                .findFirst();
    }

    public Reajuste reajustaPreco(JdbcTemplate jdbc, int codigo, BigDecimal percentual) {
        return jdbc.queryForObject(
                "CALL sp_tx_reajusta_preco_gabriel(?, ?)",
                (rs, rowNum) -> new Reajuste(
                        rs.getInt("procodigo"),
                        rs.getString("pronome"),
                        rs.getBigDecimal("preco_anterior"),
                        rs.getBigDecimal("preco_novo")
                ),
                codigo,
                percentual
        );
    }
}
