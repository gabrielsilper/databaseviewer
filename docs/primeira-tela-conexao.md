# Primeira tela: conexão com um banco MySQL

Este documento descreve a primeira funcionalidade do Database Viewer sem alterar o código da aplicação. A ideia é que você implemente cada parte manualmente, execute os testes e entenda o motivo de cada decisão.

## Objetivo

O usuário deverá informar:

- host;
- porta;
- nome do banco;
- usuário;
- senha.

Ao enviar o formulário, a aplicação deverá:

1. validar os campos;
2. criar uma conexão com o MySQL;
3. executar uma consulta simples (`SELECT 1`);
4. gerar um UUID para identificar essa conexão;
5. guardar a conexão em memória;
6. guardar somente o UUID na sessão do navegador;
7. permitir que consultas futuras recuperem o `JdbcTemplate` dessa sessão.

Nesta primeira versão, cada sessão terá uma conexão própria. As conexões serão perdidas quando a aplicação reiniciar.

## Como as peças se relacionam

```text
Navegador
   |
   | GET /database/connect
   v
Controller --------> Template Thymeleaf
   |
   | POST /database/connect
   v
Service -----------> HikariDataSource -----------> MySQL
   |
   +----------------> JdbcTemplate
   |
   +----------------> ConnectionRegistry
                              |
                              +-- UUID -> DataSource + JdbcTemplate

HttpSession guarda apenas o UUID.
```

### Por que não guardar a conexão na sessão?

Uma `HttpSession` é usada para dados associados ao usuário, mas não é o lugar ideal para controlar o ciclo de vida de uma conexão JDBC. A sessão guardará apenas o identificador:

```text
databaseConnectionId = "uuid-da-conexao"
```

O registro em memória manterá os objetos pesados (`DataSource` e `JdbcTemplate`). Assim, a senha não será colocada diretamente na sessão nem em campos exibidos pelo Thymeleaf.

## Passo 1 — criar a página Thymeleaf

Crie o diretório:

```text
src/main/resources/templates/database
```

Depois crie `connect.html`:

```html
<!DOCTYPE html>
<html lang="pt-BR" xmlns:th="http://www.thymeleaf.org">
<head>
    <meta charset="UTF-8">
    <title>Conectar ao banco</title>
</head>
<body>
<main>
    <h1>Conectar ao banco MySQL</h1>

    <p th:if="${successMessage}" th:text="${successMessage}"></p>
    <p th:if="${errorMessage}" th:text="${errorMessage}"></p>

    <p th:if="${connectionId}">
        Conectado. ID da conexão:
        <code th:text="${connectionId}"></code>
    </p>

    <form th:action="@{/database/connect}"
          th:object="${connectionForm}"
          method="post">

        <label for="host">Host</label>
        <input id="host" type="text" th:field="*{host}" placeholder="localhost">
        <small th:if="${errors['host']}" th:text="${errors['host']}"></small>

        <label for="port">Porta</label>
        <input id="port" type="number" th:field="*{port}" placeholder="3306">
        <small th:if="${errors['port']}" th:text="${errors['port']}"></small>

        <label for="database">Banco</label>
        <input id="database" type="text" th:field="*{database}" placeholder="meu_banco">
        <small th:if="${errors['database']}" th:text="${errors['database']}"></small>

        <label for="username">Usuário</label>
        <input id="username" type="text" th:field="*{username}">
        <small th:if="${errors['username']}" th:text="${errors['username']}"></small>

        <label for="password">Senha</label>
        <input id="password" type="password" th:field="*{password}">
        <small th:if="${errors['password']}" th:text="${errors['password']}"></small>

        <button type="submit">Conectar</button>
    </form>
</main>
</body>
</html>
```

O `th:object` informa qual objeto representa o formulário. O `th:field` conecta cada input a uma propriedade Java. Por exemplo, `th:field="*{host}"` lê e escreve a propriedade `host`.

## Passo 2 — criar o objeto do formulário

Crie `src/main/java/com/github/gabrielsilper/databaseviewer/connection/ConnectionForm.java`:

```java
package com.github.gabrielsilper.databaseviewer.connection;

public class ConnectionForm {

    private String host = "localhost";
    private int port = 3306;
    private String database;
    private String username;
    private String password;

    public String getHost() {
        return host;
    }

    public void setHost(String host) {
        this.host = host;
    }

    public int getPort() {
        return port;
    }

    public void setPort(int port) {
        this.port = port;
    }

    public String getDatabase() {
        return database;
    }

    public void setDatabase(String database) {
        this.database = database;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }
}
```

Esse objeto representa os dados enviados pelo formulário. Ele não representa uma conexão e não deve ser usado para executar queries.

## Passo 3 — representar uma conexão ativa

Crie `ConnectionContext.java` no mesmo pacote:

```java
package com.github.gabrielsilper.databaseviewer.connection;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.jdbc.core.JdbcTemplate;

public record ConnectionContext(
        HikariDataSource dataSource,
        JdbcTemplate jdbcTemplate
) implements AutoCloseable {

    @Override
    public void close() {
        dataSource.close();
    }
}
```

O `HikariDataSource` é o `DataSource` usado para abrir e gerenciar conexões. O `JdbcTemplate` recebe esse `DataSource` e simplifica a execução de SQL.

## Passo 4 — criar o registro em memória

Crie `ConnectionRegistry.java`:

```java
package com.github.gabrielsilper.databaseviewer.connection;

import org.springframework.stereotype.Component;

import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

@Component
public class ConnectionRegistry {

    private final ConcurrentMap<UUID, ConnectionContext> connections =
            new ConcurrentHashMap<>();

    public UUID register(ConnectionContext context) {
        UUID id = UUID.randomUUID();
        connections.put(id, context);
        return id;
    }

    public ConnectionContext get(UUID id) {
        return connections.get(id);
    }

    public ConnectionContext remove(UUID id) {
        return connections.remove(id);
    }

    public void close(UUID id) {
        ConnectionContext context = remove(id);
        if (context != null) {
            context.close();
        }
    }
}
```

`ConcurrentHashMap` é usado porque várias requisições podem acessar o registro ao mesmo tempo.

## Passo 5 — criar o serviço de conexão

Crie `DatabaseConnectionService.java`:

```java
package com.github.gabrielsilper.databaseviewer.connection;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class DatabaseConnectionService {

    private final ConnectionRegistry registry;

    public DatabaseConnectionService(ConnectionRegistry registry) {
        this.registry = registry;
    }

    public UUID connect(ConnectionForm form) {
        validate(form);

        HikariConfig config = new HikariConfig();
        config.setJdbcUrl(
                "jdbc:mysql://%s:%d/%s"
                        .formatted(form.getHost(), form.getPort(), form.getDatabase())
        );
        config.setUsername(form.getUsername());
        config.setPassword(form.getPassword());
        config.setMaximumPoolSize(2);
        config.setPoolName("database-viewer-" + UUID.randomUUID());

        HikariDataSource dataSource = new HikariDataSource(config);

        try {
            JdbcTemplate jdbcTemplate = new JdbcTemplate(dataSource);

            // Abre a conexão e confirma que as credenciais e o banco funcionam.
            jdbcTemplate.queryForObject("SELECT 1", Integer.class);

            return registry.register(
                    new ConnectionContext(dataSource, jdbcTemplate)
            );
        } catch (RuntimeException exception) {
            // Se a validação falhar, não deixe um pool aberto na memória.
            dataSource.close();
            throw exception;
        }
    }

    public ConnectionContext get(UUID id) {
        ConnectionContext context = registry.get(id);

        if (context == null) {
            throw new IllegalArgumentException("Conexão não encontrada");
        }

        return context;
    }

    public void close(UUID id) {
        registry.close(id);
    }

    private void validate(ConnectionForm form) {
        if (isBlank(form.getHost())) {
            throw new IllegalArgumentException("Host é obrigatório");
        }
        if (form.getPort() < 1 || form.getPort() > 65535) {
            throw new IllegalArgumentException("Porta deve estar entre 1 e 65535");
        }
        if (isBlank(form.getDatabase())) {
            throw new IllegalArgumentException("Banco é obrigatório");
        }
        if (isBlank(form.getUsername())) {
            throw new IllegalArgumentException("Usuário é obrigatório");
        }
        if (form.getPassword() == null) {
            throw new IllegalArgumentException("Senha é obrigatória");
        }
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
```

### O papel do `JdbcTemplate`

O `JdbcTemplate` não cria uma conexão sozinho. Ele recebe um `DataSource` e pede conexões a esse objeto quando executa uma operação.

Nesta implementação:

```java
JdbcTemplate jdbcTemplate = new JdbcTemplate(dataSource);
jdbcTemplate.queryForObject("SELECT 1", Integer.class);
```

O primeiro argumento é o SQL. O segundo informa para qual tipo o resultado deve ser convertido.

Mais tarde, uma consulta simples poderia ser:

```java
List<String> tables = jdbcTemplate.queryForList(
        "SHOW TABLES",
        String.class
);
```

Não concatene valores fornecidos pelo usuário em SQL. Para valores de filtros, use parâmetros:

```java
String sql = "SELECT nome FROM clientes WHERE id = ?";
String nome = jdbcTemplate.queryForObject(sql, String.class, id);
```

## Passo 6 — associar a conexão à sessão

Crie `ConnectionSessionBinding.java`:

```java
package com.github.gabrielsilper.databaseviewer.connection;

import jakarta.servlet.http.HttpSessionBindingEvent;
import jakarta.servlet.http.HttpSessionBindingListener;

import java.util.UUID;

public class ConnectionSessionBinding implements HttpSessionBindingListener {

    private final ConnectionRegistry registry;
    private final UUID connectionId;

    public ConnectionSessionBinding(
            ConnectionRegistry registry,
            UUID connectionId
    ) {
        this.registry = registry;
        this.connectionId = connectionId;
    }

    @Override
    public void valueUnbound(HttpSessionBindingEvent event) {
        registry.close(connectionId);
    }
}
```

Quando esse objeto for removido ou a sessão for invalidada, o servlet container chama `valueUnbound`. Isso permite fechar o pool da conexão.

## Passo 7 — substituir o controller atual

Substitua o conteúdo de `DatabaseViewerController.java` por:

```java
package com.github.gabrielsilper.databaseviewer.controller;

import com.github.gabrielsilper.databaseviewer.connection.ConnectionForm;
import com.github.gabrielsilper.databaseviewer.connection.ConnectionRegistry;
import com.github.gabrielsilper.databaseviewer.connection.ConnectionSessionBinding;
import com.github.gabrielsilper.databaseviewer.connection.DatabaseConnectionService;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.util.UUID;

@Controller
@RequestMapping("/database/connect")
public class DatabaseViewerController {

    private static final String CONNECTION_ID = "databaseConnectionId";
    private static final String CONNECTION_BINDING = "databaseConnectionBinding";

    private final DatabaseConnectionService connectionService;
    private final ConnectionRegistry connectionRegistry;

    public DatabaseViewerController(
            DatabaseConnectionService connectionService,
            ConnectionRegistry connectionRegistry
    ) {
        this.connectionService = connectionService;
        this.connectionRegistry = connectionRegistry;
    }

    @GetMapping
    public String showForm(HttpSession session, Model model) {
        model.addAttribute("connectionForm", new ConnectionForm());
        model.addAttribute("connectionId", session.getAttribute(CONNECTION_ID));
        return "database/connect";
    }

    @PostMapping
    public String connect(
            @ModelAttribute("connectionForm") ConnectionForm form,
            HttpSession session,
            RedirectAttributes redirectAttributes
    ) {
        try {
            UUID connectionId = connectionService.connect(form);

            removePreviousConnection(session);

            session.setAttribute(CONNECTION_ID, connectionId.toString());
            session.setAttribute(
                    CONNECTION_BINDING,
                    new ConnectionSessionBinding(connectionRegistry, connectionId)
            );

            redirectAttributes.addFlashAttribute(
                    "successMessage",
                    "Conexão realizada com sucesso."
            );
        } catch (RuntimeException exception) {
            redirectAttributes.addFlashAttribute(
                    "errorMessage",
                    "Não foi possível conectar: " + readableMessage(exception)
            );
        }

        return "redirect:/database/connect";
    }

    private void removePreviousConnection(HttpSession session) {
        session.removeAttribute(CONNECTION_BINDING);
        session.removeAttribute(CONNECTION_ID);
    }

    private String readableMessage(RuntimeException exception) {
        if (exception.getMessage() == null || exception.getMessage().isBlank()) {
            return "verifique os dados informados e tente novamente";
        }
        return exception.getMessage();
    }
}
```

### Por que usar `@Controller`?

`@RestController` normalmente retorna dados diretamente no corpo da resposta, como JSON ou texto. `@Controller` permite retornar o nome de um template:

```java
return "database/connect";
```

O Spring procura então:

```text
src/main/resources/templates/database/connect.html
```

### Por que redirecionar depois do POST?

Esse é o padrão Post/Redirect/Get. Depois que o formulário é enviado, o navegador recebe um redirect para o GET. Assim, atualizar a página não reenvia o formulário.

## Passo 8 — evitar o DataSource automático do Spring Boot

O Spring Boot normalmente tenta criar um `DataSource` global usando propriedades como `spring.datasource.url`. Neste projeto, a conexão só existe depois que o usuário preenche o formulário.

Por isso, adicione a exclusão da auto-configuração em `DatabaseviewerApplication.java`:

```java
package com.github.gabrielsilper.databaseviewer;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration;

@SpringBootApplication(exclude = DataSourceAutoConfiguration.class)
public class DatabaseviewerApplication {

    public static void main(String[] args) {
        SpringApplication.run(DatabaseviewerApplication.class, args);
    }
}
```

Se a sua versão do Spring Boot indicar um pacote diferente para `DataSourceAutoConfiguration`, use o pacote sugerido pela própria IDE. O ponto importante é desabilitar a tentativa de criar uma conexão global sem URL configurada.

Não coloque usuário ou senha no `application.properties`, pois eles vêm do formulário.

## Passo 9 — testar manualmente

Primeiro confirme que a aplicação sobe sem um MySQL disponível:

```bash
./gradlew test
```

Depois execute a aplicação:

```bash
./gradlew bootRun
```

Acesse:

```text
http://localhost:8080/database/connect
```

Para testar uma conexão real, você precisa ter um MySQL acessível e informar dados equivalentes a:

```text
Host: localhost
Porta: 3306
Banco: database_viewer_test
Usuário: root
Senha: sua-senha
```

## Checklist de entendimento

Antes de seguir para a tela de queries, confirme se você consegue explicar:

- a diferença entre `@Controller` e `@RestController`;
- como o nome retornado pelo controller encontra o HTML;
- como `th:field` conecta um input a uma propriedade Java;
- por que o `JdbcTemplate` precisa de um `DataSource`;
- por que o UUID fica na sessão e o `DataSource` fica no registro;
- por que o `DataSource` precisa ser fechado;
- por que o POST redireciona para um GET;
- por que não devemos colocar a senha em logs ou na sessão.

## Próxima etapa

Depois de implementar e testar este fluxo, a próxima etapa será criar um serviço que leia o UUID da sessão, recupere o `ConnectionContext` e execute uma primeira query segura, provavelmente para listar as tabelas do banco.

Não avance para essa etapa antes de confirmar que uma conexão inválida fecha corretamente o `DataSource` e que uma conexão válida aparece com um UUID na tela.
