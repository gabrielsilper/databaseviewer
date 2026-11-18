-- =====================================================================
-- TESTES DE PROCEDURES E TRANSAÇÕES
-- =====================================================================
-- Pré-requisitos:
--   1. Banco do Dump20260727.sql carregado.
--   2. aula-26-10-26.sql (tabela funcionariocomissao, sp_ajusta_fc_comissao
--      e trigger tg_atualiza_saldo_produto).
--   3. create_procedures.sql.
--
-- COMO RODAR OS TESTES DE ISOLAMENTO (partes 1 a 4):
--   É preciso ter DUAS CONEXÕES DIFERENTES com o banco, uma para a
--   SESSÃO A e outra para a SESSÃO B. Exemplo, em dois terminais:
--       docker exec -it apdb mysql -uroot -proot apdb
--   No Workbench, abra duas conexões. Duas abas da MESMA conexão
--   compartilham a sessão e não servem para o teste.
--
--   Execute os passos NA ORDEM DOS NÚMEROS, cada um na sessão indicada
--   ([SESSÃO A] ou [SESSÃO B]).
--
-- Resumo dos níveis (do mais "solto" para o mais "rígido"):
--   nível              | leitura suja | leitura não repetível | fantasma
--   READ UNCOMMITTED   |     sim      |         sim           |   sim
--   READ COMMITTED     |     não      |         sim           |   sim
--   REPEATABLE READ    |     não      |         não           |   não*
--   SERIALIZABLE       |     não      |         não           |   não
--   * no InnoDB (MySQL), o snapshot do REPEATABLE READ também evita
--     fantasmas em selects normais.
--
-- Para ver o nível atual da sessão:
--   select @@transaction_isolation;
-- =====================================================================


-- =====================================================================
-- PARTE 1 - READ UNCOMMITTED -> LEITURA SUJA (dirty read)
-- =====================================================================
-- Melhor caso de uso: painel/dashboard "em tempo real" em que a
-- velocidade importa mais que a exatidão (ex.: estoque ou preço
-- aproximado na tela). A leitura não espera nem trava nada, mas pode
-- mostrar um dado que NUNCA foi confirmado.
-- ---------------------------------------------------------------------

-- 1) [SESSÃO A] altera o preço SEM confirmar
start transaction;
call sp_reajusta_preco_produto(21, 50);    -- +50%, ainda sem commit
call sp_consulta_produto(21);              -- A vê 1800.00

-- 2) [SESSÃO B] lê no READ UNCOMMITTED
set session transaction isolation level read uncommitted;
call sp_consulta_produto(21);              -- B vê 1800.00 -> LEITURA SUJA!

-- 3) [SESSÃO A] desiste da alteração
rollback;

-- 4) [SESSÃO B] lê de novo
call sp_consulta_produto(21);              -- B vê 1200.00: o 1800 que ele leu nunca existiu
set session transaction isolation level repeatable read;   -- volta ao padrão


-- =====================================================================
-- PARTE 2 - READ COMMITTED -> SEM LEITURA SUJA, MAS LEITURA NÃO REPETÍVEL
-- =====================================================================
-- Melhor caso de uso: consulta de preço/saldo no balcão ou no caixa,
-- em que você sempre quer o ÚLTIMO valor CONFIRMADO, e não importa se
-- ele mudar entre uma consulta e outra. É o padrão do PostgreSQL,
-- do Oracle e do SQL Server.
-- ---------------------------------------------------------------------

-- 1) [SESSÃO B] abre a transação no READ COMMITTED e lê
set session transaction isolation level read committed;
start transaction;
call sp_consulta_produto(21);              -- B vê 1200.00

-- 2) [SESSÃO A] altera SEM confirmar
select propreco into @preco_original_21 from produto where procodigo = 21;
start transaction;
call sp_reajusta_preco_produto(21, 10);    -- +10% => 1320.00, sem commit

-- 3) [SESSÃO B] lê de novo
call sp_consulta_produto(21);              -- B ainda vê 1200.00 -> NÃO há leitura suja

-- 4) [SESSÃO A] confirma
commit;

-- 5) [SESSÃO B] lê de novo, NA MESMA TRANSAÇÃO
call sp_consulta_produto(21);              -- B vê 1320.00 -> LEITURA NÃO REPETÍVEL
-- (mesma consulta, mesma transação, resultado diferente)
commit;
set session transaction isolation level repeatable read;   -- volta ao padrão

-- 6) [SESSÃO A] limpeza: volta o preço original
update produto set propreco = @preco_original_21 where procodigo = 21;


-- =====================================================================
-- PARTE 3 - REPEATABLE READ (padrão do MySQL) -> "FOTO" CONSISTENTE
-- =====================================================================
-- Melhor caso de uso: relatório de fechamento / comissão do mês. Todas
-- as consultas do relatório precisam bater entre si, mesmo que entrem
-- vendas novas enquanto ele roda. A primeira leitura tira uma "foto"
-- (snapshot) e a transação inteira enxerga essa foto.
-- ---------------------------------------------------------------------

-- 1) [SESSÃO B] começa o "relatório" do mês atual do vendedor 9
set session transaction isolation level repeatable read;
start transaction;
call sp_total_vendas_vendedor(9, year(curdate()), month(curdate()));
-- anote qtde_vendas e valor_total (pode vir vazio se não houver vendas no mês)

-- 2) [SESSÃO A] registra uma venda nova para o vendedor 9 (a sp faz commit sozinha)
call sp_registra_venda(300, 2, 8, 9, 1, 21, 1);

-- 3) [SESSÃO B] repete a consulta, NA MESMA TRANSAÇÃO
call sp_total_vendas_vendedor(9, year(curdate()), month(curdate()));
-- MESMO resultado do passo 1: a venda 300 não aparece (o relatório fica consistente)

-- 4) [SESSÃO B] fecha a transação e consulta de novo
commit;
call sp_total_vendas_vendedor(9, year(curdate()), month(curdate()));
-- agora a venda 300 aparece

-- Observação importante: mesmo no REPEATABLE READ, "select ... for update"
-- lê o valor MAIS RECENTE e trava a linha. Por isso a sp_baixa_saldo_produto
-- usa "for update": o saldo do estoque não pode ser lido da "foto antiga".

-- 5) [SESSÃO A] limpeza (opcional): desfaz a venda 300
--    (saldo volta, e a comissão é recalculada pela procedure da aula)
start transaction;
delete from itemvenda where itvvencodigo = 300;
delete from venda where vencodigo = 300;
update produto set prosaldo = prosaldo + 1 where procodigo = 21;
commit;
delete from funcionariocomissao where fcfuncodigo = 9;   -- recalcula a comissão do zero
call sp_ajusta_fc_comissao(9);


-- =====================================================================
-- PARTE 4 - SERIALIZABLE -> DISPUTA PELO ÚLTIMO ITEM DO ESTOQUE
-- =====================================================================
-- Melhor caso de uso: operações em que NENHUMA anomalia é aceitável,
-- como dois caixas tentando vender a última unidade de um produto.
-- No SERIALIZABLE, todo select normal vira "select ... for share"
-- (trava de leitura). Se as duas sessões leram o saldo e as duas tentam
-- baixar, o MySQL detecta um DEADLOCK e cancela uma delas: só uma
-- venda leva o item.
-- (Sem isso, no REPEATABLE READ e SEM "for update", as duas leriam
-- saldo 1, as duas "venderiam", e uma atualização se perderia.)
-- ---------------------------------------------------------------------

-- 0) [SESSÃO A] preparação: deixa o produto 7 com saldo 1
select prosaldo into @saldo_original_7 from produto where procodigo = 7;
update produto set prosaldo = 1 where procodigo = 7;

-- 1) [SESSÃO A]
set session transaction isolation level serializable;
start transaction;
call sp_consulta_produto(7);               -- A vê saldo 1 (e trava a linha para leitura)

-- 2) [SESSÃO B]
set session transaction isolation level serializable;
start transaction;
call sp_consulta_produto(7);               -- B também vê saldo 1 (trava de leitura compartilhada)

-- 3) [SESSÃO A] tenta baixar o saldo
call sp_baixa_saldo_produto(7, 1);         -- FICA ESPERANDO: B tem trava de leitura na linha

-- 4) [SESSÃO B] tenta baixar o saldo
call sp_baixa_saldo_produto(7, 1);
-- ERRO 1213: Deadlock found when trying to get lock; try restarting transaction
-- o MySQL escolhe uma vítima (aqui, B), desfaz a transação dela,
-- e A é liberada e conclui a baixa

-- 5) [SESSÃO A] confirma
commit;
call sp_consulta_produto(7);               -- saldo 0: só UMA venda levou o último item

-- 6) [SESSÃO B] tenta de novo (como sugere a mensagem de erro)
start transaction;
call sp_baixa_saldo_produto(7, 1);         -- erro "Saldo insuficiente": correto!
rollback;

-- 7) [AS DUAS SESSÕES] voltam ao padrão
set session transaction isolation level repeatable read;

-- 8) [SESSÃO A] limpeza: volta o saldo original do produto 7
update produto set prosaldo = @saldo_original_7 where procodigo = 7;


-- =====================================================================
-- PARTE 5 - GRAN FINALE: FLUXO DE VENDA (uma sessão só)
-- =====================================================================
-- sp_registra_venda faz, em UMA transação:
--   venda -> baixa saldo (for update) -> itemvenda (+ trigger da comissão)
--   -> commit
-- Se qualquer passo falhar: rollback de TUDO.
-- ---------------------------------------------------------------------

-- ESTADO ANTES ---------------------------------------------------------
select * from venda where vencodigo in (301, 302);
select * from itemvenda where itvvencodigo in (301, 302);
select procodigo, pronome, prosaldo from produto where procodigo in (7, 21);
select * from funcionariocomissao where fcfuncodigo = 9;

-- CENÁRIO DE SUCESSO ---------------------------------------------------
-- venda 301: filial 2, cliente 8, vendedor 9, Dinheiro, produto 21, qtde 2
call sp_registra_venda(301, 2, 8, 9, 1, 21, 2);

select * from venda where vencodigo = 301;            -- a venda existe
select * from itemvenda where itvvencodigo = 301;     -- o item existe
select procodigo, pronome, prosaldo from produto
where procodigo = 21;                                 -- saldo do 21 caiu 2
select * from funcionariocomissao where fcfuncodigo = 9;  -- comissão do mês atualizada

-- CENÁRIO DE FALHA -----------------------------------------------------
-- venda 302: os dados da venda são válidos, então a venda É INSERIDA...
-- mas o item pede 99 unidades do produto 7, que não tem esse saldo.
-- O erro acontece depois do insert da venda -> rollback desfaz o insert.
call sp_registra_venda(302, 2, 8, 9, 1, 7, 99);
-- Error Code: 1644. Saldo insuficiente para o produto 7: saldo 3, pedido 99.

select * from venda where vencodigo = 302;            -- vazio: a venda NÃO ficou
select * from itemvenda where itvvencodigo = 302;     -- vazio
select procodigo, pronome, prosaldo from produto
where procodigo = 7;                                  -- saldo continua 3
select * from funcionariocomissao where fcfuncodigo = 9;  -- comissão igual à de depois da venda 301

-- OUTRAS FALHAS (todas terminam em rollback, nada é gravado) -----------
call sp_registra_venda(303, 2, 9999, 9, 1, 21, 1);    -- cliente inexistente
call sp_registra_venda(303, 2, 8, 9, 1, 2, 1);        -- produto 2 está inativo
call sp_registra_venda(303, 2, 8, 9, 1, 21, 0);       -- quantidade inválida
call sp_registra_venda(301, 2, 8, 9, 1, 21, 1);       -- código 301 já existe (PK)
