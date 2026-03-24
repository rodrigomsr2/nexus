package com.techcorp.nexus.orders.service;

import org.springframework.stereotype.Service;
import java.util.concurrent.atomic.AtomicLong;

@Service
public class OrderNumberGenerator {
    private final AtomicLong counter = new AtomicLong(20000);

    public String next() {
        return "NX-" + counter.incrementAndGet();
    }
}
