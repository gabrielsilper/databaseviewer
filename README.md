# Database Viewer

## Requisitos

Antes de executar o projeto, é necessário ter instalado:

- Java 21;
- Docker ou MySQL.

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

Caso o banco ainda não esteja configurado, abra o arquivo `dumpstate.sql` em uma ferramenta como o MySQL Workbench e execute o script.

Depois, abra o arquivo `create_procedures.sql`, selecione o banco `trab01` e execute o script para criar as procedures utilizadas pelo projeto.

## 3. Executar pela IntelliJ

1. Abra o projeto na IntelliJ.
2. Aguarde o Gradle baixar as dependências.
3. Execute a classe `DatabaseviewerApplication`.
4. Acesse no navegador:

```text
http://localhost:8080/database/connect
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
http://localhost:8080/database/connect
```

## 5. Dados de conexão na aplicação

Na tela de conexão, informe:

```text
Host: localhost
Porta: 3306
Banco: trab01
Usuário: root
Senha: root
```
