package com.techcorp.nexus.logistics.service;

import com.techcorp.nexus.logistics.adapter.TransportadoraAdapter;
import com.techcorp.nexus.logistics.adapter.TransportadoraAdapter.ShippingQuote;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Comparator;
import java.util.List;

/**
 * Seleciona automaticamente a transportadora com base em:
 * - CEP de destino
 * - Peso e dimensões do pacote
 * - Prazo de entrega desejado
 * - Menor custo para o mesmo prazo
 *
 * Transportadoras indisponíveis (isHealthy() == false) são excluídas.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ShippingSelector {

    private final List<TransportadoraAdapter> adapters;

    public ShippingQuote selectBest(String cepDestino, double weightKg, int[] dimensionsCm, int maxDays) {
        var quotes = adapters.stream()
            .filter(a -> {
                boolean healthy = a.isHealthy();
                if (!healthy) log.warn("Transportadora {} indisponível, excluída da cotação", a.getCarrierId());
                return healthy;
            })
            .map(a -> a.quote(cepDestino, weightKg, dimensionsCm))
            .filter(q -> q.estimatedDays() <= maxDays)
            .sorted(Comparator.comparing(ShippingQuote::price))
            .toList();

        if (quotes.isEmpty()) {
            throw new IllegalStateException("Nenhuma transportadora disponível para CEP " + cepDestino);
        }

        var selected = quotes.get(0);
        log.info("Transportadora selecionada: {} — R$ {} em {} dias",
            selected.carrierId(), selected.price(), selected.estimatedDays());
        return selected;
    }

    public TransportadoraAdapter getAdapter(String carrierId) {
        return adapters.stream()
            .filter(a -> a.getCarrierId().equals(carrierId))
            .findFirst()
            .orElseThrow(() -> new IllegalArgumentException("Transportadora não encontrada: " + carrierId));
    }
}
