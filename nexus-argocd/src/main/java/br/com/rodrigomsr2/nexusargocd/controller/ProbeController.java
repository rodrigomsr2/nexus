package br.com.rodrigomsr2.nexusargocd.controller;

import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;
import java.time.Instant;
import java.util.Map;

/**
 * ProbeController expõe endpoints sintéticos para geração de telemetria.
 *
 * Cada endpoint representa uma "família" de status HTTP e existe para
 * alimentar métricas, traces e alertas no k8s-observability-stack.
 *
 * Endpoints:
 *   GET /api/ok        → 200 OK
 *   GET /api/redirect  → 302 Found  (Location: /api/ok)
 *   GET /api/not-found → 404 Not Found
 *   GET /api/error     → 500 Internal Server Error
 */
@RestController
@RequestMapping("/api")
public class ProbeController {

    private final MeterRegistry meterRegistry;

    public ProbeController(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }

    // -------------------------------------------------------------------------
    // 2xx — Sucesso
    // -------------------------------------------------------------------------

    @GetMapping("/ok")
    public ResponseEntity<Map<String, Object>> ok() {
        meterRegistry.counter("probe.requests", "endpoint", "ok", "status", "2xx").increment();
        return ResponseEntity.ok(payload("ok", "Request processed successfully."));
    }

    // -------------------------------------------------------------------------
    // 3xx — Redirecionamento
    // Spring não segue o redirect automaticamente — o cliente recebe o 302.
    // -------------------------------------------------------------------------

    @GetMapping("/redirect")
    public ResponseEntity<Void> redirect() {
        meterRegistry.counter("probe.requests", "endpoint", "redirect", "status", "3xx").increment();
        return ResponseEntity.status(HttpStatus.FOUND)
                .location(URI.create("/api/ok"))
                .build();
    }

    // -------------------------------------------------------------------------
    // 4xx — Erro do cliente
    // -------------------------------------------------------------------------

    @GetMapping("/not-found")
    public ResponseEntity<Map<String, Object>> notFound() {
        meterRegistry.counter("probe.requests", "endpoint", "not-found", "status", "4xx").increment();
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(payload("not_found", "The requested resource does not exist."));
    }

    // -------------------------------------------------------------------------
    // 5xx — Erro do servidor (simulado)
    // -------------------------------------------------------------------------

    @GetMapping("/error")
    public ResponseEntity<Map<String, Object>> error() {
        meterRegistry.counter("probe.requests", "endpoint", "error", "status", "5xx").increment();
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(payload("internal_server_error", "Simulated server error for observability testing."));
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private Map<String, Object> payload(String status, String message) {
        return Map.of(
                "status", status,
                "message", message,
                "timestamp", Instant.now().toString()
        );
    }
}
