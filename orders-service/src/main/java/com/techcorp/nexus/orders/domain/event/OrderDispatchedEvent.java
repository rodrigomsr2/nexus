package com.techcorp.nexus.orders.domain.event;

import java.time.LocalDateTime;
import java.util.UUID;

public record OrderDispatchedEvent(UUID orderId, String trackingCode, String carrierId, LocalDateTime dispatchedAt) {}
