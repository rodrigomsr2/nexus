package com.techcorp.nexus.logistics.adapter;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;

@Component
@RequiredArgsConstructor
@Slf4j
public class CorreiosAdapter implements TransportadoraAdapter {

    private final RestTemplate restTemplate;

    @Override
    public String getCarrierId() { return "CORREIOS"; }

    @Override
    public ShippingQuote quote(String cepDestino, double weightKg, int[] dimensionsCm) {
        log.info("Cotando frete Correios → CEP {}", cepDestino);
        // TODO: integrar com API REST dos Correios
        return new ShippingQuote("CORREIOS", new BigDecimal("25.90"), 5);
    }

    @Override
    public String dispatch(String orderId, String cepDestino, double weightKg) {
        log.info("Despachando pedido {} via Correios", orderId);
        // TODO: chamada real à API dos Correios para gerar etiqueta
        return "JD" + System.currentTimeMillis() + "BR";
    }

    @Override
    public boolean isHealthy() {
        try {
            restTemplate.getForObject("https://api.correios.com.br/health", String.class);
            return true;
        } catch (Exception e) {
            log.warn("Correios API indisponível: {}", e.getMessage());
            return false;
        }
    }
}
