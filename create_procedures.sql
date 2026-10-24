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
