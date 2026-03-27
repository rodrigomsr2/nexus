package com.rodrigomsr2.nexus.orders.domain.model;

public enum OrderStatus {
    RASCUNHO,
    CONFIRMADO,
    EM_SEPARACAO,
    DESPACHADO,
    ENTREGUE,
    CANCELADO;

    public boolean canTransitionTo(OrderStatus next) {
        return switch (this) {
            case RASCUNHO     -> next == CONFIRMADO || next == CANCELADO;
            case CONFIRMADO   -> next == EM_SEPARACAO || next == CANCELADO;
            case EM_SEPARACAO -> next == DESPACHADO;
            case DESPACHADO   -> next == ENTREGUE;
            default           -> false;
        };
    }
}
