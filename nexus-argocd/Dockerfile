# =============================================================================
# Stage 1 — Build
# Compila, testa e extrai o JAR em layers para otimizar cache Docker
# =============================================================================
FROM eclipse-temurin:21.0.7_6-jdk-alpine-3.21 AS builder

WORKDIR /build

# Copia os arquivos de configuração do Gradle separados do source.
# A camada de dependências só é invalidada quando esses arquivos mudam.
COPY build.gradle settings.gradle ./
COPY gradle ./gradle
COPY gradlew ./

RUN chmod +x gradlew && \
    ./gradlew dependencies --no-daemon -q

# Copia o source e executa build completo (compile + test + bootJar)
COPY src ./src
RUN ./gradlew bootJar --no-daemon -q && \
    java -Djarmode=layertools \
         -jar build/libs/nexus-argocd-*.jar \
         extract --destination /build/layers

# =============================================================================
# Stage 2 — Runtime
# Imagem base própria + layers do Spring Boot na ordem correta de volatilidade
# =============================================================================
FROM ghcr.io/rodrigomsr2/base-images/java-21-alpine:1.1.0

# Layers do Spring Boot em ordem crescente de volatilidade:
# dependencies     — JARs de terceiros (mudam raramente)
# snapshot-dependencies — dependências SNAPSHOT (mudam às vezes)
# spring-boot-loader — loader do Spring Boot (muda com versão do Boot)
# application      — código da aplicação (muda com frequência)
COPY --chown=appuser:appgroup --from=builder /build/layers/dependencies/          ./
COPY --chown=appuser:appgroup --from=builder /build/layers/snapshot-dependencies/ ./
COPY --chown=appuser:appgroup --from=builder /build/layers/spring-boot-loader/    ./
COPY --chown=appuser:appgroup --from=builder /build/layers/application/           ./

EXPOSE 8080
EXPOSE 8081

# Sobrescreve o CMD da imagem base para iniciar a aplicação Spring Boot
CMD ["java", "org.springframework.boot.loader.launch.JarLauncher"]
