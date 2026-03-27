package com.rodrigomsr2.nexus.orders.controller;

import com.rodrigomsr2.nexus.orders.domain.model.Order;
import com.rodrigomsr2.nexus.orders.service.OrderService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    // POST /api/v1/orders — cria rascunho
    @PostMapping
    @PreAuthorize("hasAnyRole('BUYER','SALES','ADMIN')")
    public ResponseEntity<Order> createOrder(@RequestBody Order order) {
        return ResponseEntity.status(HttpStatus.CREATED).body(orderService.createDraft(order));
    }

    // GET /api/v1/orders/{id} — detalha pedido
    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('BUYER','SALES','LOGISTICS','ADMIN')")
    public ResponseEntity<Order> getOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(orderService.findById(id));
    }

    // PUT /api/v1/orders/{id}/submit — confirma pedido
    @PutMapping("/{id}/submit")
    @PreAuthorize("hasAnyRole('BUYER','SALES','ADMIN')")
    public ResponseEntity<Order> submitOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(orderService.submitOrder(id));
    }

    // DELETE /api/v1/orders/{id} — cancela pedido
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('BUYER','SALES','ADMIN')")
    public ResponseEntity<Order> cancelOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(orderService.cancelOrder(id));
    }

    // GET /api/v1/orders?clientId=X — lista pedidos do cliente
    @GetMapping
    @PreAuthorize("hasAnyRole('BUYER','SALES','ADMIN')")
    public ResponseEntity<List<Order>> listOrders(@RequestParam(required = false) String clientId) {
        if (clientId != null) {
            return ResponseEntity.ok(orderService.findByClientId(clientId));
        }
        return ResponseEntity.badRequest().build();
    }
}
