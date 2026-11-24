-- =====================================================================
-- PROCEDURES DO PROJETO
-- =====================================================================

-- Minha procedure para listar os nomes dos bancos
drop procedure if exists sp_lista_nomes_bancos_gabriel;
delimiter $$
create procedure sp_lista_nomes_bancos_gabriel()
begin
    SELECT
        schema_name as nome_banco
    FROM
        information_schema.SCHEMATA
    ORDER BY schema_name;
end$$
delimiter ;

-- Minha procedure para listar os nomes das tabelas
drop procedure if exists sp_lista_nomes_tabelas_gabriel;
delimiter $$
create procedure sp_lista_nomes_tabelas_gabriel(p_schema varchar(50))
begin
    SELECT
        TABLE_NAME
    FROM
        information_schema.TABLES
    WHERE
        TABLE_SCHEMA = p_schema
    ORDER BY TABLE_NAME;
end$$
delimiter ;

-- Minha procedure para listar os nomes das colunas, os seus tipos e se são nulas ou não
drop procedure if exists sp_lista_nomes_colunas_gabriel;
delimiter $$
create procedure sp_lista_nomes_colunas_gabriel(p_schema varchar(50), p_table_name varchar(50))
begin
    SELECT
        COLUMN_NAME as nome_coluna,
        DATA_TYPE as tipo_coluna,
        IS_NULLABLE as is_nula
    FROM
        information_schema.COLUMNS
    WHERE
        TABLE_SCHEMA = p_schema
          AND TABLE_NAME = p_table_name
    ORDER BY ORDINAL_POSITION;
end$$
delimiter ;

-- Minha procedures para listar os nomes das tabelas lado 1 e lado n
drop procedure if exists sp_lista_nomes_tabelas_lado_1_gabriel;
delimiter $$
create procedure sp_lista_nomes_tabelas_lado_1_gabriel(
    p_schema varchar(50),
    p_table_name varchar(50)
)
begin
    SELECT
        REFERENCED_TABLE_NAME as nome_tabela
    FROM
        information_schema.KEY_COLUMN_USAGE
    WHERE
        TABLE_SCHEMA = p_schema
      AND TABLE_NAME = p_table_name
      AND REFERENCED_TABLE_SCHEMA = p_schema
      AND REFERENCED_TABLE_NAME IS NOT NULL
    ORDER BY TABLE_NAME;
end$$
delimiter ;

drop procedure if exists sp_lista_nomes_tabelas_lado_n_gabriel;
delimiter $$
create procedure sp_lista_nomes_tabelas_lado_n_gabriel(
    p_schema varchar(50),
    p_table_name varchar(50)
)
begin
    SELECT
        TABLE_NAME as nome_tabela
    FROM
        information_schema.KEY_COLUMN_USAGE
    WHERE
        REFERENCED_TABLE_SCHEMA = p_schema
      AND REFERENCED_TABLE_NAME = p_table_name
      AND TABLE_SCHEMA = p_schema
    ORDER BY TABLE_NAME;
end$$
delimiter ;


-- =====================================================================
-- LISTAGENS (alimentam as tabelas e os selects das páginas)
-- =====================================================================

-- Todos os produtos (página de reajuste)
drop procedure if exists sp_lista_produtos_gabriel;
delimiter $$
create procedure sp_lista_produtos_gabriel()
begin
    SELECT
        procodigo,
        pronome,
        propreco,
        prosaldo,
        proativo
    FROM
        produto
    ORDER BY procodigo;
end$$
delimiter ;

-- Só os produtos ativos (select da página de venda)
drop procedure if exists sp_lista_produtos_ativos_gabriel;
delimiter $$
create procedure sp_lista_produtos_ativos_gabriel()
begin
    SELECT
        procodigo,
        pronome,
        propreco,
        prosaldo,
        proativo
    FROM
        produto
    WHERE
        proativo = '1'
    ORDER BY pronome;
end$$
delimiter ;

-- Vendedores: a tabela vendedor só tem o código, ela especializa
-- funcionario. O nome vem do join com funcionario.
-- ativo = 1 quando o funcionário não foi desligado (fundtdem is null).
drop procedure if exists sp_lista_vendedores_gabriel;
delimiter $$
create procedure sp_lista_vendedores_gabriel()
begin
    SELECT
        vefuncodigo as codigo,
        funnome as nome,
        (fundtdem is null) as ativo
    FROM
        vendedor
            join funcionario on funcodigo = vefuncodigo
    ORDER BY funnome;
end$$
delimiter ;

drop procedure if exists sp_lista_filiais_gabriel;
delimiter $$
create procedure sp_lista_filiais_gabriel()
begin
    SELECT
        filcodigo as codigo,
        filnome as nome
    FROM
        filial
    ORDER BY filnome;
end$$
delimiter ;

drop procedure if exists sp_lista_clientes_ativos_gabriel;
delimiter $$
create procedure sp_lista_clientes_ativos_gabriel()
begin
    SELECT
        clicodigo as codigo,
        clinome as nome
    FROM
        cliente
    WHERE
        clidtdesativacao is null
    ORDER BY clinome;
end$$
delimiter ;

drop procedure if exists sp_lista_formas_pagamento_ativas_gabriel;
delimiter $$
create procedure sp_lista_formas_pagamento_ativas_gabriel()
begin
    SELECT
        fpcodigo as codigo,
        fpdescricao as nome
    FROM
        formapagamento
    WHERE
        fpativo = 1
    ORDER BY fpcodigo;
end$$
delimiter ;


-- =====================================================================
-- PRODUTO: consulta e reajuste
-- =====================================================================

-- Minha procedure para consultar preço e saldo de um produto
drop procedure if exists sp_consulta_produto_gabriel;
delimiter $$
create procedure sp_consulta_produto_gabriel(p_procodigo int)
begin
    SELECT
        procodigo,
        pronome,
        propreco,
        prosaldo,
        proativo
    FROM
        produto
    WHERE
        procodigo = p_procodigo;
end$$
delimiter ;

-- Minha procedure para reajustar o preço de um produto em um percentual
drop procedure if exists sp_reajusta_preco_produto_gabriel;
delimiter $$
create procedure sp_reajusta_preco_produto_gabriel(p_procodigo int, p_percentual double)
begin
    if not exists (select 1 from produto where procodigo = p_procodigo) then
        signal sqlstate '45000' set message_text = 'Produto não encontrado.';
    end if;

    if p_percentual is null or p_percentual <= -100 then
        signal sqlstate '45000' set message_text = 'Percentual de reajuste inválido (deve ser maior que -100).';
    end if;

    UPDATE produto
    SET propreco = propreco * (1 + p_percentual / 100)
    WHERE procodigo = p_procodigo;
end$$
delimiter ;


-- =====================================================================
-- RELATÓRIO DO VENDEDOR
-- =====================================================================
-- Observação: itemvenda não guarda o preço da venda, então os valores
-- usam o propreco ATUAL do produto.

-- Resumo do mês: quantidade de vendas, valor total e comissão do mês.
-- Sempre devolve UMA linha (zeros quando não houve venda no mês).
drop procedure if exists sp_total_vendas_vendedor_gabriel;
delimiter $$
create procedure sp_total_vendas_vendedor_gabriel(p_funcodigo int, p_ano int, p_mes int)
begin
    if not exists (select 1 from vendedor where vefuncodigo = p_funcodigo) then
        signal sqlstate '45000' set message_text = 'Vendedor não encontrado.';
    end if;

    SELECT
        vefuncodigo as vendedor,
        funnome as nome,
        COALESCE(t.qtde_vendas, 0) as qtde_vendas,
        COALESCE(t.valor_total, 0) as valor_total,
        COALESCE(fcvalor, 0) as comissao
    FROM
        vendedor
            join funcionario on funcodigo = vefuncodigo
            left join (
                SELECT
                    venfuncodigo,
                    COUNT(DISTINCT vencodigo) as qtde_vendas,
                    SUM(propreco * itvqtde) as valor_total
                FROM
                    venda
                        join itemvenda on itvvencodigo = vencodigo
                        join produto on procodigo = itvprocodigo
                WHERE
                    venfuncodigo = p_funcodigo
                  AND YEAR(vendata) = p_ano
                  AND MONTH(vendata) = p_mes
                GROUP BY venfuncodigo
            ) t on t.venfuncodigo = vefuncodigo
            left join funcionariocomissao on fcfuncodigo = vefuncodigo
                                         and fcano = p_ano
                                         and fcmes = p_mes
    WHERE
        vefuncodigo = p_funcodigo;
end$$
delimiter ;

-- Minha procedure para consultar o histórico de comissões
drop procedure if exists sp_lista_comissoes_vendedor_gabriel;
delimiter $$
create procedure sp_lista_comissoes_vendedor_gabriel(p_funcodigo int)
begin
    SELECT
        fcano as ano,
        fcmes as mes,
        fcvalor as valor
    FROM
        funcionariocomissao
    WHERE
        fcfuncodigo = p_funcodigo
    ORDER BY fcano desc, fcmes desc;
end$$
delimiter ;


-- =====================================================================
-- VENDA (etapas; a transação fica na sp_tx_registra_venda_gabriel, no fim do arquivo)
-- =====================================================================
-- Fluxo, dentro de UMA transação:
--   sp_abre_venda_gabriel -> sp_adiciona_item_venda_gabriel
--     -> sp_baixa_saldo_produto_gabriel
--     -> insert itemvenda
--   -> commit (ou rollback de tudo se qualquer etapa der signal/erro)

-- =====================================================================

-- Minha procedure para dar baixa no saldo (estoque) de um produto
drop procedure if exists sp_baixa_saldo_produto_gabriel;
delimiter $$
create procedure sp_baixa_saldo_produto_gabriel(p_procodigo int, p_qtde int)
begin
    declare v_saldo int default null;
    declare v_msg varchar(128);

    SELECT prosaldo into v_saldo
    FROM produto
    WHERE procodigo = p_procodigo;

    if v_saldo is null then
        set v_msg = concat('Produto ', p_procodigo, ' não encontrado.');
        signal sqlstate '45000' set message_text = v_msg;
    end if;

    if v_saldo < p_qtde then
        set v_msg = concat('Saldo insuficiente para o produto ', p_procodigo,
                           ': saldo ', v_saldo, ', pedido ', p_qtde, '.');
        signal sqlstate '45000' set message_text = v_msg;
    end if;

    UPDATE produto
    SET prosaldo = prosaldo - p_qtde
    WHERE procodigo = p_procodigo;
end$$
delimiter ;

-- Etapa 1 da venda: valida os dados e insere o cabeçalho na tabela venda
drop procedure if exists sp_abre_venda_gabriel;
delimiter $$
create procedure sp_abre_venda_gabriel(
    p_vencodigo int,
    p_filcodigo int,
    p_clicodigo int,
    p_funcodigo int,
    p_fpcodigo smallint
)
begin
    if p_vencodigo is null or p_vencodigo <= 0 then
        signal sqlstate '45000' set message_text = 'Código da venda deve ser maior que zero.';
    end if;

    if exists (select 1 from venda where vencodigo = p_vencodigo) then
        signal sqlstate '45000' set message_text = 'Já existe uma venda com esse código.';
    end if;

    if not exists (select 1 from filial where filcodigo = p_filcodigo) then
        signal sqlstate '45000' set message_text = 'Filial não encontrada.';
    end if;

    if not exists (select 1 from cliente
                   where clicodigo = p_clicodigo
                     and clidtdesativacao is null) then
        signal sqlstate '45000' set message_text = 'Cliente não encontrado ou desativado.';
    end if;

    if not exists (select 1 from vendedor
                       join funcionario on funcodigo = vefuncodigo
                   where vefuncodigo = p_funcodigo
                     and fundtdem is null) then
        signal sqlstate '45000' set message_text = 'Vendedor não encontrado ou desligado.';
    end if;

    if not exists (select 1 from formapagamento
                   where fpcodigo = p_fpcodigo
                     and fpativo = 1) then
        signal sqlstate '45000' set message_text = 'Forma de pagamento não encontrada ou inativa.';
    end if;

    INSERT INTO venda (vencodigo, vendata, venfilcodigo, venclicodigo, venfuncodigo, venfpcodigo)
    VALUES (p_vencodigo, curdate(), p_filcodigo, p_clicodigo, p_funcodigo, p_fpcodigo);
end$$
delimiter ;

-- Etapa 2 da venda: adiciona um item, dando baixa no saldo do produto
drop procedure if exists sp_adiciona_item_venda_gabriel;
delimiter $$
create procedure sp_adiciona_item_venda_gabriel(p_vencodigo int, p_procodigo int, p_qtde int)
begin
    declare v_msg varchar(128);

    if p_qtde is null or p_qtde <= 0 then
        signal sqlstate '45000' set message_text = 'Quantidade do item deve ser maior que zero.';
    end if;

    if not exists (select 1 from venda where vencodigo = p_vencodigo) then
        signal sqlstate '45000' set message_text = 'Venda não encontrada.';
    end if;

    if not exists (select 1 from produto
                   where procodigo = p_procodigo
                     and proativo = '1') then
        set v_msg = concat('Produto ', coalesce(p_procodigo, 'NULL'), ' não encontrado ou inativo.');
        signal sqlstate '45000' set message_text = v_msg;
    end if;

    call sp_baixa_saldo_produto_gabriel(p_procodigo, p_qtde);

    INSERT INTO itemvenda (itvvencodigo, itvprocodigo, itvqtde)
    VALUES (p_vencodigo, p_procodigo, p_qtde);
end$$
delimiter ;


-- =====================================================================
-- TRANSAÇÕES
-- =====================================================================
-- Cada sp_tx_ é UMA transação completa

-- Venda completa (1 item): cabeçalho + baixa de saldo + item
drop procedure if exists sp_tx_registra_venda_gabriel;
delimiter $$
create procedure sp_tx_registra_venda_gabriel(
    p_vencodigo int,
    p_filcodigo int,
    p_clicodigo int,
    p_funcodigo int,
    p_fpcodigo smallint,
    p_procodigo int,
    p_qtde int
)
begin
    declare exit handler for sqlexception
    begin
        rollback;
        resignal;
    end;

    start transaction;

    call sp_abre_venda_gabriel(p_vencodigo, p_filcodigo, p_clicodigo, p_funcodigo, p_fpcodigo);
    call sp_adiciona_item_venda_gabriel(p_vencodigo, p_procodigo, p_qtde);

    commit;
end$$
delimiter ;

-- Reajuste de preço: devolve o preço anterior e o novo
drop procedure if exists sp_tx_reajusta_preco_gabriel;
delimiter $$
create procedure sp_tx_reajusta_preco_gabriel(p_procodigo int, p_percentual double)
begin
    declare v_preco_anterior double default null;

    declare exit handler for sqlexception
    begin
        rollback;
        resignal;
    end;

    start transaction;

    SELECT propreco into v_preco_anterior
    FROM produto
    WHERE procodigo = p_procodigo;

    -- valida (produto existe, percentual > -100) e faz o update
    call sp_reajusta_preco_produto_gabriel(p_procodigo, p_percentual);

    commit;

    SELECT
        procodigo,
        pronome,
        v_preco_anterior as preco_anterior,
        propreco as preco_novo
    FROM
        produto
    WHERE
        procodigo = p_procodigo;
end$$
delimiter ;


-- Minha procedure para gerar o relatório (comissão) do vendedor no mês
drop procedure if exists sp_ajusta_fc_comissao_gabriel;
delimiter $$
create procedure sp_ajusta_fc_comissao_gabriel(p_funcodigo int, p_ano int, p_mes int)
begin
    INSERT INTO funcionariocomissao (fcfuncodigo, fcano, fcmes, fcvalor)
    SELECT
        venfuncodigo,
        YEAR(vendata),
        MONTH(vendata),
        ROUND(SUM(propreco * itvqtde * (grpcomissao / 100)), 2)
    FROM
        itemvenda
            JOIN venda ON vencodigo = itvvencodigo
            JOIN produto ON procodigo = itvprocodigo
            JOIN grupoproduto ON grpcodigo = progrpcodigo
    WHERE
        venfuncodigo = p_funcodigo
      AND YEAR(vendata) = p_ano
      AND MONTH(vendata) = p_mes
    GROUP BY
        venfuncodigo,
        YEAR(vendata),
        MONTH(vendata)
    ON DUPLICATE KEY UPDATE
        fcvalor = VALUES(fcvalor);
end$$
delimiter ;
