-- =====================================================================
-- PROCEDURES DO PROJETO
-- Rode DEPOIS do dumpstate.sql, no banco apdb.
-- O script pode ser executado mais de uma vez (drop procedure if exists).
-- =====================================================================

-- Minha procedure para listar os nomes dos bancos
drop procedure if exists sp_lista_nomes_bancos;
delimiter $$
create procedure sp_lista_nomes_bancos()
begin
    SELECT
        schema_name as nome_banco
    FROM
        information_schema.SCHEMATA
    ORDER BY schema_name;
end$$
delimiter ;

-- Minha procedure para listar os nomes das tabelas
drop procedure if exists sp_lista_nomes_tabelas;
delimiter $$
create procedure sp_lista_nomes_tabelas(p_schema varchar(50))
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
drop procedure if exists sp_lista_nomes_colunas;
delimiter $$
create procedure sp_lista_nomes_colunas(p_schema varchar(50), p_table_name varchar(50))
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
drop procedure if exists sp_lista_nomes_tabelas_lado_1;
delimiter $$
create procedure sp_lista_nomes_tabelas_lado_1(
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

drop procedure if exists sp_lista_nomes_tabelas_lado_n;
delimiter $$
create procedure sp_lista_nomes_tabelas_lado_n(
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
drop procedure if exists sp_lista_produtos;
delimiter $$
create procedure sp_lista_produtos()
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
drop procedure if exists sp_lista_produtos_ativos;
delimiter $$
create procedure sp_lista_produtos_ativos()
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
drop procedure if exists sp_lista_vendedores;
delimiter $$
create procedure sp_lista_vendedores()
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

drop procedure if exists sp_lista_filiais;
delimiter $$
create procedure sp_lista_filiais()
begin
    SELECT
        filcodigo as codigo,
        filnome as nome
    FROM
        filial
    ORDER BY filnome;
end$$
delimiter ;

drop procedure if exists sp_lista_clientes_ativos;
delimiter $$
create procedure sp_lista_clientes_ativos()
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

drop procedure if exists sp_lista_formas_pagamento_ativas;
delimiter $$
create procedure sp_lista_formas_pagamento_ativas()
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
-- (é a "leitura" usada nos testes de isolamento)
drop procedure if exists sp_consulta_produto;
delimiter $$
create procedure sp_consulta_produto(p_procodigo int)
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
-- (é a "escrita" usada nos testes de isolamento)
drop procedure if exists sp_reajusta_preco_produto;
delimiter $$
create procedure sp_reajusta_preco_produto(p_procodigo int, p_percentual double)
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
drop procedure if exists sp_total_vendas_vendedor;
delimiter $$
create procedure sp_total_vendas_vendedor(p_funcodigo int, p_ano int, p_mes int)
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

-- Detalhe do mês: cada venda do vendedor com cliente e valor
drop procedure if exists sp_lista_vendas_vendedor;
delimiter $$
create procedure sp_lista_vendas_vendedor(p_funcodigo int, p_ano int, p_mes int)
begin
    SELECT
        vencodigo as venda,
        vendata as data,
        clinome as cliente,
        SUM(propreco * itvqtde) as valor
    FROM
        venda
            join cliente on clicodigo = venclicodigo
            join itemvenda on itvvencodigo = vencodigo
            join produto on procodigo = itvprocodigo
    WHERE
        venfuncodigo = p_funcodigo
      AND YEAR(vendata) = p_ano
      AND MONTH(vendata) = p_mes
    GROUP BY vencodigo, vendata, clinome
    ORDER BY vendata, vencodigo;
end$$
delimiter ;

-- Histórico de comissões (tabela funcionariocomissao, mantida pelo trigger)
drop procedure if exists sp_lista_comissoes_vendedor;
delimiter $$
create procedure sp_lista_comissoes_vendedor(p_funcodigo int)
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
-- VENDA (etapas; a transação fica na sp_tx_registra_venda, no fim do arquivo)
-- =====================================================================
-- Fluxo, dentro de UMA transação:
--   sp_abre_venda -> sp_adiciona_item_venda
--     -> sp_baixa_saldo_produto (for update)
--     -> insert itemvenda -> trigger tg_atualiza_saldo_produto (comissão)
--   -> commit (ou rollback de tudo se qualquer etapa der signal/erro)

-- Minha procedure para dar baixa no saldo (estoque) de um produto
-- O "for update" trava a linha do produto até o fim da transação:
-- outra sessão que tentar baixar o mesmo produto fica esperando,
-- assim duas vendas não vendem o mesmo item ao mesmo tempo.
drop procedure if exists sp_baixa_saldo_produto;
delimiter $$
create procedure sp_baixa_saldo_produto(p_procodigo int, p_qtde int)
begin
    declare v_saldo int default null;
    declare v_msg varchar(128);

    SELECT prosaldo into v_saldo
    FROM produto
    WHERE procodigo = p_procodigo
        FOR UPDATE;

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
drop procedure if exists sp_abre_venda;
delimiter $$
create procedure sp_abre_venda(
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
-- O insert em itemvenda dispara o trigger tg_atualiza_saldo_produto
-- (aula 26/10, criado no dumpstate.sql), que recalcula a comissão do
-- vendedor no mês da venda. Como o trigger roda DENTRO da mesma
-- transação, um rollback desfaz a comissão também.
drop procedure if exists sp_adiciona_item_venda;
delimiter $$
create procedure sp_adiciona_item_venda(p_vencodigo int, p_procodigo int, p_qtde int)
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

    -- primeiro trava e baixa o saldo (se não tiver saldo, já para aqui)
    call sp_baixa_saldo_produto(p_procodigo, p_qtde);

    INSERT INTO itemvenda (itvvencodigo, itvprocodigo, itvqtde)
    VALUES (p_vencodigo, p_procodigo, p_qtde);
end$$
delimiter ;


-- =====================================================================
-- TRANSAÇÕES
-- =====================================================================
-- Cada sp_tx_ é UMA transação completa: abre, chama as procedures de
-- etapa acima (que não abrem transação) e confirma.
-- O exit handler pega QUALQUER erro (signal das etapas, chave duplicada,
-- deadlock...): faz rollback de tudo e, com o resignal, devolve o MESMO
-- erro para quem chamou (Java ou Workbench).
-- A aplicação Java só faz: CALL sp_tx_...(...)

-- Venda completa (1 item): cabeçalho + baixa de saldo + item + comissão
drop procedure if exists sp_tx_registra_venda;
delimiter $$
create procedure sp_tx_registra_venda(
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

    call sp_abre_venda(p_vencodigo, p_filcodigo, p_clicodigo, p_funcodigo, p_fpcodigo);
    -- baixa o saldo (for update), insere o item e o trigger atualiza a comissão
    call sp_adiciona_item_venda(p_vencodigo, p_procodigo, p_qtde);

    commit;
end$$
delimiter ;

-- Reajuste de preço: devolve o preço anterior e o novo
drop procedure if exists sp_tx_reajusta_preco;
delimiter $$
create procedure sp_tx_reajusta_preco(p_procodigo int, p_percentual double)
begin
    declare v_preco_anterior double default null;

    declare exit handler for sqlexception
    begin
        rollback;
        resignal;
    end;

    start transaction;

    -- trava a linha: ninguém muda o preço entre esta leitura e o update
    SELECT propreco into v_preco_anterior
    FROM produto
    WHERE procodigo = p_procodigo
        FOR UPDATE;

    -- valida (produto existe, percentual > -100) e faz o update
    call sp_reajusta_preco_produto(p_procodigo, p_percentual);

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
