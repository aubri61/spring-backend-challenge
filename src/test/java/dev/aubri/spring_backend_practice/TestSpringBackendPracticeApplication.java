package dev.aubri.spring_backend_practice;

import org.springframework.boot.SpringApplication;

public class TestSpringBackendPracticeApplication {

	public static void main(String[] args) {
		SpringApplication.from(SpringBackendPracticeApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
