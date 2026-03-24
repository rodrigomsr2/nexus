package com.techcorp.nexus.orders.domain.event;

import java.math.BigDecimal;
import java.util.UUID;

public record OrderCancelledEvent(UUID orderId, BigDecimal cancellationFee) {}
