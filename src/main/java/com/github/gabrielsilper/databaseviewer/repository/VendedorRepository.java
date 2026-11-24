package com.github.gabrielsilper.databaseviewer.repository;

import com.github.gabrielsilper.databaseviewer.model.Comissao;
import com.github.gabrielsilper.databaseviewer.model.ResumoVendedor;
import com.github.gabrielsilper.databaseviewer.model.Vendedor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class VendedorRepository {

    public List<Vendedor> listaVendedores(JdbcTemplate jdbc) {
        return jdbc.query(
                "CALL sp_lista_vendedores_gabriel()",
                (rs, rowNum) -> new Vendedor(
                        rs.getInt("codigo"),
                        rs.getString("nome"),
                        rs.getBoolean("ativo")
                )
        );
    }

    public ResumoVendedor totalVendas(JdbcTemplate jdbc, int vendedor, int ano, int mes) {
        return jdbc.queryForObject(
                "CALL sp_total_vendas_vendedor_gabriel(?, ?, ?)",
                (rs, rowNum) -> new ResumoVendedor(
                        rs.getInt("vendedor"),
                        rs.getString("nome"),
                        rs.getInt("qtde_vendas"),
                        rs.getBigDecimal("comissao")
                ),
                vendedor,
                ano,
                mes
        );
    }

    public void geraRelatorio(JdbcTemplate jdbc, int vendedor, int ano, int mes) {
        jdbc.update("CALL sp_ajusta_fc_comissao_gabriel(?, ?, ?)", vendedor, ano, mes);
    }

    public List<Comissao> listaComissoes(JdbcTemplate jdbc, int vendedor) {
        return jdbc.query(
                "CALL sp_lista_comissoes_vendedor_gabriel(?)",
                (rs, rowNum) -> new Comissao(
                        rs.getInt("ano"),
                        rs.getInt("mes"),
                        rs.getBigDecimal("valor")
                ),
                vendedor
        );
    }
}
