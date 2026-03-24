package com.techcorp.nexus.orders.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "orders")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(unique = true, nullable = false)
    private String orderNumber; // formato: NX-XXXXX

    @Column(nullable = false)
    private String clientId;

    @Column(nullable = false)
    private String clientType; // PJ ou PF

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OrderStatus status;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<OrderItem> items = new ArrayList<>();

    @Column(precision = 15, scale = 2)
    private BigDecimal subtotal;

    @Column(precision = 5, scale = 2)
    private BigDecimal discountPercent;

    @Column(precision = 15, scale = 2)
    private BigDecimal total;

    private String trackingCode;
    private String carrierId;

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    private LocalDateTime confirmedAt;
    private LocalDateTime dispatchedAt;
    private LocalDateTime deliveredAt;

    // Regra de negócio: desconto 3% para pedidos > R$5.000 (ADR-003 compatible)
    public void applyVolumeDiscount() {
        if (subtotal != null && subtotal.compareTo(new BigDecimal("5000.00")) > 0) {
            this.discountPercent = new BigDecimal("3.00");
            this.total = subtotal.multiply(new BigDecimal("0.97"));
        } else {
            this.discountPercent = BigDecimal.ZERO;
            this.total = subtotal;
        }
    }

    // Regra de negócio: pedido mínimo por tipo de cliente
    public boolean meetsMinimumOrder() {
        BigDecimal minimum = "PJ".equals(clientType)
            ? new BigDecimal("500.00")
            : new BigDecimal("100.00");
        return total != null && total.compareTo(minimum) >= 0;
    }

    // Regra de negócio: janela de cancelamento gratuito (2h após confirmação)
    public boolean isWithinFreeCancellationWindow() {
        if (confirmedAt == null) return true;
        return LocalDateTime.now().isBefore(confirmedAt.plusHours(2));
    }

    public BigDecimal getCancellationFee() {
        if (isWithinFreeCancellationWindow()) return BigDecimal.ZERO;
        return total.multiply(new BigDecimal("0.05"));
    }
}
