package com.rodrigomsr2.nexus.logistics.adapter;

import java.math.BigDecimal;
import java.util.Map;

/**
 * Interface de integração com transportadoras.
 *
 * Implementações:
 *  - CorreiosAdapter  → REST API
 *  - JadlogAdapter    → SOAP (legado)
 *  - RapidaoAdapter   → REST API
 *
 * Seleção automática baseada em CEP, peso, prazo e custo.
 */
public interface TransportadoraAdapter {

    String getCarrierId();

    /** Cotação de frete */
    ShippingQuote quote(String cepDestino, double weightKg, int[] dimensionsCm);

    /** Despacha o pedido e retorna código de rastreamento */
    String dispatch(String orderId, String cepDestino, double weightKg);

    /** Verifica saúde da integração (usado pelo ShippingSelector) */
    boolean isHealthy();

    record ShippingQuote(String carrierId, BigDecimal price, int estimatedDays) {}
}
