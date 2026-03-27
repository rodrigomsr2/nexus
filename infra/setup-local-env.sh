#!/usr/bin/env bash
# setup-local-env.sh — bootstrapa o ambiente de desenvolvimento local do Nexus
#
# O que faz:
#   1. Verifica/instala dependencias (k3s, helm, yq)
#   2. Detecta o IP do host e grava .env para o Docker Compose
#   3. Sobe a infra pelo Docker Compose (postgres, redis, kafka, keycloak)
#   4. Cria namespace, secrets e Services externos no k3s
#   5. Instala o ArgoCD e aguarda ficar pronto
#   6. Aplica o ArgoCD Application (nexus)
#   7. Exibe o resumo de acesso
#
# Pre-requisitos:
#   - Docker + Docker Compose v2 instalados
#   - Usuario com acesso sudo (necessario para instalar k3s, helm, yq)
#
# Uso:
#   chmod +x setup-local-env.sh
#   ./setup-local-env.sh

set -euo pipefail

# ── Constantes ────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAMESPACE="nexus"
ARGOCD_NAMESPACE="argocd"
K3S_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
YQ_VERSION="v4.40.5"

# ── Cores ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[nexus]${NC} $*"; }
warn() { echo -e "${YELLOW}[ warn]${NC} $*"; }
err()  { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }
step() { echo -e "\n${BLUE}══════ $* ══════${NC}"; }

# ── Deteccao do IP do host ────────────────────────────────────────────────────
detect_host_ip() {
  local iface
  iface=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -1)
  if [[ -n "$iface" ]]; then
    ip -4 addr show "$iface" | awk '/inet / {print $2}' | cut -d/ -f1 | head -1
  else
    hostname -I | awk '{print $1}'
  fi
}

HOST_IP=$(detect_host_ip)
[[ -z "$HOST_IP" ]] && err "Nao foi possivel detectar o IP do host."
log "Host IP: ${HOST_IP}"

# ── Verifica pre-requisitos ───────────────────────────────────────────────────
step "Verificando pre-requisitos"

command -v docker &>/dev/null  || err "Docker nao encontrado. Instale em: https://docs.docker.com/engine/install/"
docker compose version &>/dev/null || err "Docker Compose v2 nao encontrado. Instale o plugin: https://docs.docker.com/compose/install/"
command -v sudo &>/dev/null    || err "sudo nao encontrado."
log "Docker $(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1) OK"

# ── Instala k3s ───────────────────────────────────────────────────────────────
step "k3s"

if systemctl is-active --quiet k3s 2>/dev/null; then
  log "k3s ja em execucao."
elif command -v k3s &>/dev/null; then
  log "k3s instalado mas parado. Iniciando..."
  sudo systemctl start k3s
  log "Aguardando k3s inicializar..."
  retries_k3s=30
  until sudo k3s kubectl get nodes &>/dev/null 2>&1; do
    ((retries_k3s--)) || err "k3s nao inicializou a tempo."
    sleep 3
  done
  sudo k3s kubectl wait --for=condition=Ready node --all --timeout=120s
  log "k3s pronto."
else
  log "Instalando k3s (requer sudo)..."
  curl -sfL https://get.k3s.io | sudo sh -s - --write-kubeconfig-mode 644
  log "Aguardando k3s inicializar..."
  retries_k3s=30
  until sudo k3s kubectl get nodes &>/dev/null 2>&1; do
    ((retries_k3s--)) || err "k3s nao inicializou a tempo."
    sleep 3
  done
  sudo k3s kubectl wait --for=condition=Ready node --all --timeout=120s
  log "k3s pronto."
fi

# Merge do kubeconfig do k3s no ~/.kube/config (preserva contextos existentes)
mkdir -p "$HOME/.kube"
if [[ -f "$HOME/.kube/config" ]]; then
  # Faz backup antes de qualquer alteracao
  cp "$HOME/.kube/config" "$HOME/.kube/config.bak"
  KUBECONFIG="$HOME/.kube/config:$K3S_KUBECONFIG" \
    kubectl config view --flatten > "$HOME/.kube/config.merged"
  mv "$HOME/.kube/config.merged" "$HOME/.kube/config"
  log "kubeconfig do k3s mergeado em ~/.kube/config (backup em ~/.kube/config.bak)"
else
  sudo cp "$K3S_KUBECONFIG" "$HOME/.kube/config"
  sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
  log "kubeconfig criado em ~/.kube/config"
fi
export KUBECONFIG="$HOME/.kube/config"

# ── Instala Helm ──────────────────────────────────────────────────────────────
step "Helm"

if command -v helm &>/dev/null; then
  log "Helm ja instalado ($(helm version --short 2>/dev/null))."
else
  log "Instalando Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash
  log "Helm instalado."
fi

# ── Instala yq ────────────────────────────────────────────────────────────────
step "yq"

if command -v yq &>/dev/null; then
  log "yq ja instalado."
else
  log "Instalando yq ${YQ_VERSION}..."
  sudo wget -qO /usr/local/bin/yq \
    "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
  sudo chmod +x /usr/local/bin/yq
  log "yq instalado."
fi

# ── Corrige iptables para comunicacao entre containers Docker ─────────────────
# k3s/Flannel muda a politica FORWARD para DROP, bloqueando redes Docker.
# Permitimos apenas trafego nas interfaces bridge do Docker (nao abre globalmente).
step "iptables — comunicacao Docker"

# k3s ativa bridge-nf-call-iptables=1, fazendo trafego entre containers Docker
# passar pelo iptables com interfaces veth (nao br-xxx). --physdev-is-bridged
# faz match apenas em trafego interno de bridge, sem expor internet.
sudo iptables -C FORWARD -m physdev --physdev-is-bridged -j ACCEPT 2>/dev/null || \
  sudo iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT
log "Regras iptables para Docker aplicadas."

# ── Grava .env para o Docker Compose ─────────────────────────────────────────
step "Configurando .env"

cat > "${REPO_ROOT}/.env" <<EOF
# Gerado por setup-local-env.sh — nao edite manualmente
HOST_IP=${HOST_IP}
EOF
log ".env criado (HOST_IP=${HOST_IP})"

# ── Sobe infra via Docker Compose ─────────────────────────────────────────────
step "Infra Docker Compose"

cd "$REPO_ROOT"
docker compose up -d postgres redis zookeeper kafka keycloak kafka-ui

log "Aguardando PostgreSQL ficar saudavel..."
retries=30
until docker compose exec -T postgres pg_isready -U nexus_user -d nexus &>/dev/null; do
  ((retries--)) || err "PostgreSQL nao ficou saudavel a tempo."
  sleep 3
done
log "PostgreSQL pronto."

log "Aguardando Kafka inicializar (30s)..."
sleep 30
log "Kafka pronto."

# ── Namespace e secrets no k3s ────────────────────────────────────────────────
step "Namespace e secrets"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic nexus-db-secret \
  --namespace "$NAMESPACE" \
  --from-literal=host="${HOST_IP}" \
  --from-literal=port="5432" \
  --from-literal=password="nexus_secret" \
  --dry-run=client -o yaml | kubectl apply -f -

log "Secret nexus-db-secret criado/atualizado."

# ── Services externos (Docker Compose → k3s pods) ────────────────────────────
# Os pods k3s usam nomes de servico (redis, kafka, keycloak) que precisam
# resolver para os containers Docker Compose rodando no host.
step "Services externos no k3s"

create_external_service() {
  local name=$1 svc_port=$2 host_port=$3
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${name}
  namespace: ${NAMESPACE}
spec:
  type: ClusterIP
  ports:
    - port: ${svc_port}
      targetPort: ${svc_port}
      protocol: TCP
---
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: ${name}
  namespace: ${NAMESPACE}
  labels:
    kubernetes.io/service-name: ${name}
addressType: IPv4
endpoints:
  - addresses:
      - "${HOST_IP}"
ports:
  - port: ${host_port}
    protocol: TCP
EOF
  log "Service '${name}': cluster:${svc_port} -> host:${host_port}"
}

# redis:6379         -> HOST_IP:6379
# kafka:9092         -> HOST_IP:9093 (listener PLAINTEXT_K8S do Kafka)
# keycloak:8080      -> HOST_IP:8180
# postgres:5432      -> HOST_IP:5432
create_external_service redis    6379 6379
create_external_service kafka    9092 9093
create_external_service keycloak 8080 8180
create_external_service postgres 5432 5432

# ── Instala ArgoCD ────────────────────────────────────────────────────────────
step "ArgoCD"

kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

ARGOCD_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
kubectl apply -n "$ARGOCD_NAMESPACE" --server-side --force-conflicts -f "$ARGOCD_MANIFEST"

log "Aguardando ArgoCD server ficar pronto (pode levar alguns minutos)..."
kubectl rollout status deploy/argocd-server -n "$ARGOCD_NAMESPACE" --timeout=300s
log "ArgoCD pronto."

# Expoe ArgoCD via NodePort na porta 30443
kubectl patch svc argocd-server -n "$ARGOCD_NAMESPACE" \
  -p '{"spec":{"type":"NodePort","ports":[{"name":"https","port":443,"targetPort":8080,"nodePort":30443}]}}'

# ── Aplica ArgoCD Application ─────────────────────────────────────────────────
step "ArgoCD Application (nexus)"

kubectl apply -f "${REPO_ROOT}/infra/k8s/argocd/nexus-app.yaml"
log "Application 'nexus' registrada no ArgoCD."

# ── Recupera senha inicial do ArgoCD ─────────────────────────────────────────
ARGOCD_PASSWORD=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "(nao disponivel ainda — tente: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)")

# ── Resumo ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Nexus — Ambiente local pronto!                    ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${GREEN}║${NC}  %-20s %s\n" "Host IP:"           "${HOST_IP}"
printf "${GREEN}║${NC}  %-20s %s\n" "ArgoCD UI:"         "https://${HOST_IP}:30443"
printf "${GREEN}║${NC}  %-20s %s\n" "ArgoCD login:"      "admin / ${ARGOCD_PASSWORD}"
printf "${GREEN}║${NC}  %-20s %s\n" "Kafka UI:"          "http://${HOST_IP}:8090"
printf "${GREEN}║${NC}  %-20s %s\n" "Keycloak:"          "http://${HOST_IP}:8180  (admin/admin)"
printf "${GREEN}║${NC}  %-20s %s\n" "API Gateway (k3s):" "http://${HOST_IP}:30080"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  Fluxo GitOps:"
echo -e "${GREEN}║${NC}    1. Push de codigo -> GitHub Actions builda + push para GHCR"
echo -e "${GREEN}║${NC}    2. ./deploy.sh <service> <tag>  atualiza values.yaml + push"
echo -e "${GREEN}║${NC}    3. ArgoCD detecta mudanca no Git e sincroniza automaticamente"
echo -e "${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  Forccar sync manual:"
echo -e "${GREEN}║${NC}    kubectl -n argocd get app nexus"
echo -e "${GREEN}║${NC}    kubectl -n argocd patch app nexus -p '{\"operation\":{\"sync\":{}}}' --type merge"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
