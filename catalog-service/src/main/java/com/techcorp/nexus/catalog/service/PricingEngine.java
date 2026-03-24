package com.techcorp.nexus.catalog.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;

/**
 * Resolve o preço final de um produto para um cliente específico.
 *
 * Prioridade (conforme documentação):
 * 1. Preço contratual específico do cliente
 * 2. Preço contratual do grupo do cliente
 * 3. Campanha promocional ativa
 * 4. Preço base com desconto por volume
 * 5. Preço base
 *
 * Resultado cacheado no Redis com TTL de 15 minutos (ADR-002).
 * Cache é invalidado via CatalogUpdatedEvent quando produto é atualizado no admin.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PricingEngine {

    private final ContractPriceService contractPriceService;
    private final CampaignService campaignService;
    private final ProductService productService;

    @Cacheable(value = "pricing", key = "#sku + ':' + #clientId")
    public BigDecimal resolvePrice(String sku, String clientId) {
        log.debug("Resolvendo preço: SKU={} clientId={}", sku, clientId);

        // 1. Preço contratual específico do cliente
        var clientPrice = contractPriceService.findBySkuAndClientId(sku, clientId);
        if (clientPrice.isPresent()) {
            log.debug("Preço contratual do cliente encontrado: {}", clientPrice.get());
            return clientPrice.get();
        }

        // 2. Preço contratual do grupo do cliente
        var groupPrice = contractPriceService.findBySkuAndClientGroup(sku, clientId);
        if (groupPrice.isPresent()) {
            log.debug("Preço contratual do grupo encontrado: {}", groupPrice.get());
            return groupPrice.get();
        }

        // 3. Campanha promocional ativa
        var campaignPrice = campaignService.findActiveCampaignPrice(sku);
        if (campaignPrice.isPresent()) {
            log.debug("Preço de campanha ativa encontrado: {}", campaignPrice.get());
            return campaignPrice.get();
        }

        // 4 e 5. Preço base (desconto por volume é aplicado no OrderService)
        var basePrice = productService.getBasePrice(sku);
        log.debug("Usando preço base: {}", basePrice);
        return basePrice;
    }
}
