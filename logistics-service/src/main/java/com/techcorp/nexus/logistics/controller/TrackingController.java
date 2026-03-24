package com.techcorp.nexus.logistics.controller;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Rastreamento em tempo real via Server-Sent Events (SSE).
 * Eventos chegam via webhook das transportadoras → Kafka logistics.tracking → SSE frontend.
 */
@RestController
@RequestMapping("/api/v1/tracking")
@RequiredArgsConstructor
@Slf4j
public class TrackingController {

    // Map de emitters por orderId
    private final Map<String, SseEmitter> emitters = new ConcurrentHashMap<>();

    /**
     * Frontend se inscreve para receber eventos de rastreamento em tempo real.
     * GET /api/v1/tracking/{orderId}/stream
     */
    @GetMapping(value = "/{orderId}/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    @PreAuthorize("hasAnyRole('BUYER','SALES','LOGISTICS','ADMIN')")
    public SseEmitter streamTracking(@PathVariable String orderId) {
        SseEmitter emitter = new SseEmitter(Long.MAX_VALUE);
        emitters.put(orderId, emitter);

        emitter.onCompletion(() -> emitters.remove(orderId));
        emitter.onTimeout(() -> emitters.remove(orderId));
        emitter.onError(e -> emitters.remove(orderId));

        log.info("SSE: cliente inscrito para rastreamento do pedido {}", orderId);
        return emitter;
    }

    /**
     * Webhook das transportadoras publica no Kafka logistics.tracking.
     * Este listener consome e repassa via SSE para o frontend.
     */
    @KafkaListener(topics = "logistics.tracking", groupId = "nexus-logistics-sse")
    public void onTrackingEvent(TrackingEventMessage event) {
        SseEmitter emitter = emitters.get(event.orderId());
        if (emitter != null) {
            try {
                emitter.send(SseEmitter.event()
                    .name("tracking")
                    .data(event));
                log.info("SSE: evento de rastreamento enviado para pedido {}", event.orderId());
            } catch (IOException e) {
                emitters.remove(event.orderId());
            }
        }
    }

    /**
     * Webhook recebido diretamente das transportadoras.
     * POST /api/v1/tracking/webhook/{carrierId}
     */
    @PostMapping("/webhook/{carrierId}")
    public void receiveWebhook(@PathVariable String carrierId, @RequestBody Map<String, Object> payload) {
        log.info("Webhook recebido da transportadora {}: {}", carrierId, payload);
        // Publica no Kafka logistics.tracking para processamento assíncrono
    }

    record TrackingEventMessage(String orderId, String status, String description, String location, String timestamp) {}
}
