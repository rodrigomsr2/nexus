package com.rodrigomsr2.nexus.orders.domain.event;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

public record OrderConfirmedEvent(UUID orderId, String clientId, BigDecimal total, LocalDateTime confirmedAt) {}
