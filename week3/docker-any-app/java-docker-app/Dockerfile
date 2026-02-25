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

EXPOSE 8080
# Menjalankan aplikasi
ENTRYPOINT ["java", "-jar", "app.jar"]