# ─── Stage 1: Build ──────────────────────────────────────
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /workspace

# Copy Gradle wrapper and root build files
COPY gradlew .
COPY gradle gradle
COPY build.gradle .
COPY settings.gradle .

# Copy service build file and pre-fetch dependencies
COPY orders-service/build.gradle orders-service/build.gradle
RUN --mount=type=cache,target=/root/.gradle \
    chmod +x gradlew && ./gradlew :orders-service:dependencies --no-daemon -q

# Copy source and build
COPY orders-service/src orders-service/src
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew :orders-service:bootJar -x test --no-daemon -q

# ─── Stage 2: Extract layers ─────────────────────────────
FROM eclipse-temurin:21-jdk-alpine AS layers
WORKDIR /workspace
COPY --from=build /workspace/orders-service/build/libs/*.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract

# ─── Stage 3: Runtime ────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S nexus && adduser -S nexus -G nexus
WORKDIR /app

COPY --from=layers /workspace/dependencies/ ./
COPY --from=layers /workspace/spring-boot-loader/ ./
COPY --from=layers /workspace/snapshot-dependencies/ ./
COPY --from=layers /workspace/application/ ./

USER nexus
EXPOSE 8080

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "org.springframework.boot.loader.launch.JarLauncher"]
