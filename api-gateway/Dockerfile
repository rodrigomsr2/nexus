# ─── Stage 1: Build ──────────────────────────────────────
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /workspace

COPY gradlew .
COPY gradle gradle
COPY build.gradle .
COPY settings.gradle .

COPY api-gateway/build.gradle api-gateway/build.gradle
RUN --mount=type=cache,target=/root/.gradle \
    chmod +x gradlew && ./gradlew :api-gateway:dependencies --no-daemon -q

COPY api-gateway/src api-gateway/src
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew :api-gateway:bootJar -x test --no-daemon -q

# ─── Stage 2: Extract layers ─────────────────────────────
FROM eclipse-temurin:21-jdk-alpine AS layers
WORKDIR /workspace
COPY --from=build /workspace/api-gateway/build/libs/*.jar app.jar
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
