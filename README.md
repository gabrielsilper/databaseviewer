# Database Viewer

Aplicação Spring Boot + Thymeleaf que se conecta a um MySQL e:

- mostra bancos, tabelas, campos e relacionamentos (viewer);
- reajusta o preço de produtos;
- gera o relatório de vendas e comissão de um vendedor;
- registra uma venda.

Todo acesso ao banco é feito por **stored procedures**. As operações que
precisam ser atômicas usam procedures de transação (`sp_tx_*`).

## Requisitos

- Java 21;
- Docker ou MySQL 8.

O projeto está configurado para Java 21. Versões anteriores podem não funcionar corretamente.

## 1. Iniciar o banco de dados

### Usando Docker

Na pasta do projeto, execute:

```bash
docker compose up -d
```

### Usando MySQL instalado

Também é possível utilizar um MySQL instalado diretamente na máquina, com os seguintes dados:

```text
Host: localhost
Porta: 3306
Usuário: root
Senha: root
```

## 2. Restaurar o banco de dados

Os scripts ficam na pasta `sql/` e devem ser executados nesta ordem:

| Script | O que faz |
|---|---|
| `sql/dumpstate.sql` | Cria o banco `apdb` com tabelas e dados, a tabela `funcionariocomissao` (já com a carga inicial), a procedure `sp_ajusta_fc_comissao` e o trigger `tg_atualiza_saldo_produto` |
| `sql/create_procedures.sql` | Cria as procedures usadas pela aplicação. Pode ser executado mais de uma vez |
| `sql/testes_procedures.sql` | Opcional: roteiro de testes de transação e níveis de isolamento |

Com Docker:

```bash
docker exec -i apdb mysql -uroot -proot < sql/dumpstate.sql
docker exec -i apdb mysql -uroot -proot apdb < sql/create_procedures.sql
```

Ou abra os arquivos no MySQL Workbench e execute-os, com o banco `apdb` selecionado para o segundo.

## 3. Executar pela IntelliJ

1. Abra o projeto na IntelliJ.
2. Aguarde o Gradle baixar as dependências.
3. Execute a classe `DatabaseviewerApplication`.
4. Acesse no navegador:

```text
http://localhost:8080/connect
```

## 4. Executar pelo terminal

Na pasta do projeto, execute:

Linux/macOS:

```bash
./gradlew bootRun
```

Windows:

```bat
gradlew.bat bootRun
```

Depois, acesse:

```text
http://localhost:8080/connect
```

## 5. Dados de conexão na aplicação

Na tela de conexão, informe:

```text
Host: localhost
Porta: 3306
Banco: apdb
Usuário: root
Senha: root
```

## 6. Páginas

Depois de conectar, o menu no topo leva a todas as páginas.

| Rota | Página | Procedures |
|---|---|---|
| `/viewer` | Bancos, tabelas, campos e relacionamentos | `sp_lista_nomes_*` |
| `/produtos` | Consultar todos, consultar por código e reajustar preço | `sp_lista_produtos`, `sp_consulta_produto`, `sp_tx_reajusta_preco` |
| `/relatorio` | Relatório do vendedor no mês: nº de vendas, comissão e histórico de comissões | `sp_lista_vendedores`, `sp_total_vendas_vendedor`, `sp_lista_comissoes_vendedor` |
| `/venda` | Registrar uma venda com 1 item | listas para os selects + `sp_tx_registra_venda` |

Dica: as vendas do banco de exemplo são de 2024. Para ver um relatório com dados,
use o vendedor 9, mês 1, ano 2024.

## 7. Procedures de etapa × procedures de transação

- **Procedures de etapa** (`sp_abre_venda`, `sp_adiciona_item_venda`, `sp_baixa_saldo_produto`,
  `sp_reajusta_preco_produto`...) só leem, escrevem e validam (com `signal`). Elas **não**
  abrem transação.
- **Procedures de transação** (`sp_tx_registra_venda`, `sp_tx_reajusta_preco`) abrem a transação,
  chamam as de etapa e fazem `commit`. Um `exit handler` faz `rollback` de tudo se qualquer
  etapa falhar e devolve o erro original (`resignal`).

A aplicação Java só faz `CALL sp_tx_...(...)`. Quando dá erro, a mensagem do `signal`
(ex.: "Saldo insuficiente...") aparece na tela.

Na venda, o insert em `itemvenda` dispara o trigger que atualiza a comissão do vendedor
no mês. Como o trigger roda dentro da mesma transação, um rollback desfaz a comissão também.

## 8. Organização do código

```text
com.github.gabrielsilper.databaseviewer
├─ controller/  recebe a requisição, chama o service e monta a tela
├─ service/     regras simples e validação dos dados de entrada
├─ repository/  só executa CALL sp_... e converte o resultado em objetos
├─ model/       records com os dados que vêm do banco
├─ form/        objetos ligados aos formulários (th:object)
└─ infra/       conexão por usuário (pool Hikari na sessão HTTP) e mensagens de erro
```
