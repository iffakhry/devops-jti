# run project java di docker

1. buat project java di Spring Initializr https://start.spring.io/

```plain
Project: Maven
Language: Java
Spring Boot: default
Group: com.example
Artifact: java-docker-app
Name: java-docker-app
Packaging: Jar
Java: 17 (atau 11)
Dependencies:
✅ Spring Web
```

2. download, dan extract zip file nya
3. tambahkan controller sederhana HelloController.java

```java
package com.fakhry.java_docker_app;

import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestMapping;

@RestController
public class HelloController {

    @RequestMapping("/")
    public String index() {
        return "Hello, " + System.getenv("APP_NAME");
    }

}
```

4. buat Dockerfile

```bash
# Stage 1: Build aplikasi
FROM maven:3.8.5-openjdk-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Runtime image
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
# Menyalin hasil build dari stage pertama
COPY --from=build /app/target/*.jar app.jar

# Menjalankan aplikasi
ENTRYPOINT ["java", "-jar", "app.jar"]
```

5. buat .dockerignore

```bash
target
.git
.mvn
mvnw
mvnw.cmd
.gitignore
```

6. build image

```bash
docker build -t java-images .
```

7. create container

```bash
docker run -d -p 8080:8080 -e APP_NAME=DockerJava --name javaContainer java-images
```

notes:
pada dockerfile terdapat perintah untuk skip test. ini bukan berarti test tidak penting.
tapi lebih kepada agar mempercepat proses build image.
dan dengan asumsi proses test telah dilakukan dan sukses pada tahap sebelumnya.
