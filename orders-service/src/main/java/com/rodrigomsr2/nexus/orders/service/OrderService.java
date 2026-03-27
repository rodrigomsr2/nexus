package com.rodrigomsr2.nexus.orders.service;

import com.rodrigomsr2.nexus.orders.domain.event.OrderCancelledEvent;
import com.rodrigomsr2.nexus.orders.domain.event.OrderConfirmedEvent;
import com.rodrigomsr2.nexus.orders.domain.model.Order;
import com.rodrigomsr2.nexus.orders.domain.model.OrderStatus;
import com.rodrigomsr2.nexus.orders.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {

    private final OrderRepository orderRepository;
    private final CreditService creditService;
    private final KafkaTemplate<String, Object> kafkaTemplate;
    private final OrderNumberGenerator orderNumberGenerator;

    @Transactional
    public Order createDraft(Order order) {
        order.setStatus(OrderStatus.RASCUNHO);
        order.setOrderNumber(orderNumberGenerator.next());
        order.applyVolumeDiscount();
        return orderRepository.save(order);
    }

    @Transactional
    public Order submitOrder(UUID orderId) {
        Order order = findById(orderId);

        if (!order.getStatus().canTransitionTo(OrderStatus.CONFIRMADO)) {
            throw new IllegalStateException("Pedido não pode ser confirmado no status: " + order.getStatus());
        }

        if (!order.meetsMinimumOrder()) {
            throw new IllegalArgumentException("Pedido abaixo do valor mínimo para cliente " + order.getClientType());
        }

        // Consulta CreditService — se bloqueado, lança exceção ou envia p/ revisão manual
        creditService.validateCredit(order.getClientId(), order.getTotal());

        order.setStatus(OrderStatus.CONFIRMADO);
        order.setConfirmedAt(LocalDateTime.now());
        Order saved = orderRepository.save(order);

        // Publica evento Kafka — Logistics consome para reservar estoque (RPI)
        kafkaTemplate.send("orders.confirmed", order.getId().toString(),
            new OrderConfirmedEvent(saved.getId(), saved.getClientId(), saved.getTotal(), saved.getConfirmedAt()));

        log.info("Pedido {} confirmado — evento publicado em orders.confirmed", order.getOrderNumber());
        return saved;
    }

    @Transactional
    public Order cancelOrder(UUID orderId) {
        Order order = findById(orderId);

        if (!order.getStatus().canTransitionTo(OrderStatus.CANCELADO)) {
            throw new IllegalStateException("Pedido não pode ser cancelado no status: " + order.getStatus());
        }

        var fee = order.getCancellationFee();
        if (fee.signum() > 0) {
            log.warn("Taxa de cancelamento aplicada: R$ {} no pedido {}", fee, order.getOrderNumber());
        }

        order.setStatus(OrderStatus.CANCELADO);
        Order saved = orderRepository.save(order);

        kafkaTemplate.send("orders.cancelled", order.getId().toString(),
            new OrderCancelledEvent(saved.getId(), fee));

        return saved;
    }

    @Transactional(readOnly = true)
    public Order findById(UUID id) {
        return orderRepository.findById(id)
            .orElseThrow(() -> new jakarta.persistence.EntityNotFoundException("Pedido não encontrado: " + id));
    }

    @Transactional(readOnly = true)
    public List<Order> findByClientId(String clientId) {
        return orderRepository.findByClientIdOrderByCreatedAtDesc(clientId);
    }
}
