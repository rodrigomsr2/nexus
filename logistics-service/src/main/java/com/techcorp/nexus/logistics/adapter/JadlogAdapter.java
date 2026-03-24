package com.techcorp.nexus.logistics.adapter;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;

/**
 * Integração com Jadlog via SOAP (sistema legado).
 * Utiliza Spring-WS para comunicação com o endpoint WSDL.
 * ATENÇÃO: Jadlog apresenta latência alta em horário de pico.
 * O ShippingSelector faz failover automático para Correios se isHealthy() retornar false.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class JadlogAdapter implements TransportadoraAdapter {

    // private final JadlogWebServiceClient soapClient; // Spring-WS gerado via wsdl2java

    @Override
    public String getCarrierId() { return "JADLOG"; }

    @Override
    public ShippingQuote quote(String cepDestino, double weightKg, int[] dimensionsCm) {
        log.info("Cotando frete Jadlog (SOAP) → CEP {}", cepDestino);
        // TODO: chamar endpoint SOAP da Jadlog
        // CotacaoRequest req = new CotacaoRequest(cepDestino, weightKg);
        // CotacaoResponse resp = soapClient.cotar(req);
        return new ShippingQuote("JADLOG", new BigDecimal("19.50"), 3);
    }

    @Override
    public String dispatch(String orderId, String cepDestino, double weightKg) {
        log.info("Despachando pedido {} via Jadlog SOAP", orderId);
        // TODO: chamada SOAP para geração de etiqueta
        return "JDL" + System.currentTimeMillis();
    }

    @Override
    public boolean isHealthy() {
        try {
            // TODO: ping no endpoint SOAP da Jadlog
            return true;
        } catch (Exception e) {
            log.warn("Jadlog SOAP indisponível — failover será ativado: {}", e.getMessage());
            return false;
        }
    }
}
