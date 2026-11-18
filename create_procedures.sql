-- Minha procedure para listar os nomes dos bancos
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

-- PROCEDURES PARA O ESTUDO DE TRANSAÇÕES E NÍVEIS DE ISOLAMENTO
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
        prosaldo
    FROM
        produto
    WHERE
        procodigo = p_procodigo;
end$$
delimiter ;

-- Minha procedure para o total vendido por um vendedor em um mês/ano
-- (leitura de "relatório", usada no teste do REPEATABLE READ)
drop procedure if exists sp_total_vendas_vendedor;
delimiter $$
create procedure sp_total_vendas_vendedor(p_funcodigo int, p_ano int, p_mes int)
begin
    SELECT
        venfuncodigo as vendedor,
        COUNT(DISTINCT vencodigo) as qtde_vendas,
        COALESCE(SUM(propreco * itvqtde), 0) as valor_total
    FROM
        venda
            join itemvenda on itvvencodigo = vencodigo
            join produto on procodigo = itvprocodigo
    WHERE
        venfuncodigo = p_funcodigo
      AND YEAR(vendata) = p_ano
      AND MONTH(vendata) = p_mes
    GROUP BY venfuncodigo;
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
    if not exists (select 1 from filial where filcodigo = p_filcodigo) then
        signal sqlstate '45000' set message_text = 'Filial não encontrada.';
    end if;

    if not exists (select 1 from cliente
                   where clicodigo = p_clicodigo
                     and clidtdesativacao is null) then
        signal sqlstate '45000' set message_text = 'Cliente não encontrado ou desativado.';
    end if;

    if not exists (select 1 from vendedor where vefuncodigo = p_funcodigo) then
        signal sqlstate '45000' set message_text = 'Vendedor não encontrado.';
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
-- (aula 26/10), que recalcula a comissão do vendedor. Como o trigger
-- roda DENTRO da mesma transação, um rollback desfaz a comissão também.
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

-- Registra a venda completa em UMA transação
-- Recebe os dados da venda e UM item (produto + quantidade).
-- Fluxo: abre a venda -> baixa o saldo do produto (for update)
-- -> insere o item (+ trigger de comissão) -> commit.
-- Se QUALQUER etapa falhar, o exit handler faz rollback de tudo
-- (venda, item, saldo e comissão) e repassa o erro (resignal).
-- Roda no nível padrão (REPEATABLE READ): o "for update" da baixa de
-- saldo já trava só a linha do produto vendido, o que é melhor do
-- que SERIALIZABLE, que trava todas as linhas lidas.
drop procedure if exists sp_registra_venda;
delimiter $$
create procedure sp_registra_venda(
    p_vencodigo int,
    p_filcodigo int,
    p_clicodigo int,
    p_funcodigo int,
    p_fpcodigo smallint,
    p_procodigo int,
    p_qtde int
)
begin
    begin
        rollback;
    end;

    start transaction;

    call sp_abre_venda(p_vencodigo, p_filcodigo, p_clicodigo, p_funcodigo, p_fpcodigo);
    call sp_adiciona_item_venda(p_vencodigo, p_procodigo, p_qtde);

    commit;

    SELECT concat('Venda ', p_vencodigo, ' registrada.') as resposta;
end$$
delimiter ;
