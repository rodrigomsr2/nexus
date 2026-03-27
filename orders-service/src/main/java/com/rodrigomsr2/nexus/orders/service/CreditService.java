package com.rodrigomsr2.nexus.orders.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;

@Service
@Slf4j
public class CreditService {

    // Na prática, chamaria um serviço externo de crédito
    public void validateCredit(String clientId, BigDecimal amount) {
        log.info("Validando crédito do cliente {} para valor {}", clientId, amount);
        // TODO: integrar com sistema de crédito real
        // Lança CreditLimitExceededException se inadimplente ou acima do limite
    }
}
