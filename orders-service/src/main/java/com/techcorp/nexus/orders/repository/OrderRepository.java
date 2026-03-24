package com.techcorp.nexus.orders.repository;

import com.techcorp.nexus.orders.domain.model.Order;
import com.techcorp.nexus.orders.domain.model.OrderStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface OrderRepository extends JpaRepository<Order, UUID> {
    List<Order> findByClientIdOrderByCreatedAtDesc(String clientId);
    List<Order> findByStatus(OrderStatus status);
    long countByStatus(OrderStatus status);
}
