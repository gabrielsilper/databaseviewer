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
