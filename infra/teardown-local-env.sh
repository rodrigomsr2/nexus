#!/usr/bin/env bash
# teardown-local-env.sh — derruba o ambiente de desenvolvimento local do Nexus
#
# O que faz:
#   1. Remove a Application e os recursos do namespace nexus do k3s
#   2. Remove o ArgoCD
#   3. Para e remove os containers Docker Compose (infra)
#
# O que NAO faz (por seguranca):
#   - Nao desinstala k3s, helm ou yq
#   - Nao apaga volumes Docker (postgres_data, redis_data) — use --volumes para isso
#   - Nao remove o kubeconfig de ~/.kube/config
#
# Uso:
#   ./teardown-local-env.sh           # para tudo, preserva volumes
#   ./teardown-local-env.sh --volumes # para tudo e apaga volumes Docker

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAMESPACE="nexus"
ARGOCD_NAMESPACE="argocd"
REMOVE_VOLUMES=false

# ── Flags ─────────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --volumes) REMOVE_VOLUMES=true ;;
    *) echo "Opcao desconhecida: $arg"; exit 1 ;;
  esac
done

# ── Cores ─────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[nexus]${NC} $*"; }
warn() { echo -e "${YELLOW}[ warn]${NC} $*"; }
step() { echo -e "\n${BLUE}══════ $* ══════${NC}"; }

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

# ── ArgoCD Application ────────────────────────────────────────────────────────
step "Removendo ArgoCD Application"

if kubectl get application nexus -n "$ARGOCD_NAMESPACE" &>/dev/null 2>&1; then
  # Desativa o sync automatico antes de deletar para o ArgoCD nao recriar os recursos
  kubectl patch application nexus -n "$ARGOCD_NAMESPACE" \
    -p '{"spec":{"syncPolicy":null}}' --type merge
  kubectl delete application nexus -n "$ARGOCD_NAMESPACE"
  log "Application 'nexus' removida."
else
  warn "Application 'nexus' nao encontrada, pulando."
fi

# ── Namespace nexus ───────────────────────────────────────────────────────────
step "Removendo namespace nexus"

force_delete_namespace() {
  local ns=$1
  warn "Namespace '$ns' preso em Terminating. Forcando remocao de finalizers..."
  kubectl get namespace "$ns" -o json \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['spec']['finalizers']=[]; print(json.dumps(d))" \
    | kubectl replace --raw "/api/v1/namespaces/${ns}/finalize" -f -
  log "Namespace '$ns' removido forcadamente."
}

delete_namespace() {
  local ns=$1 timeout=$2
  if kubectl get namespace "$ns" &>/dev/null 2>&1; then
    kubectl delete namespace "$ns" --timeout="${timeout}s" || force_delete_namespace "$ns"
    log "Namespace '$ns' removido."
  else
    warn "Namespace '$ns' nao encontrado, pulando."
  fi
}

delete_namespace "$NAMESPACE"        60

# ── ArgoCD ────────────────────────────────────────────────────────────────────
step "Removendo ArgoCD"

delete_namespace "$ARGOCD_NAMESPACE" 120

# Remove CRDs do ArgoCD
if kubectl get crd applications.argoproj.io &>/dev/null 2>&1; then
  kubectl delete crd \
    applications.argoproj.io \
    applicationsets.argoproj.io \
    appprojects.argoproj.io
  log "CRDs do ArgoCD removidos."
fi

# ── k3s ───────────────────────────────────────────────────────────────────────
step "Parando k3s"

if systemctl is-active --quiet k3s 2>/dev/null; then
  sudo systemctl stop k3s
  log "k3s parado."
else
  warn "k3s ja estava parado."
fi

# ── Docker Compose infra ──────────────────────────────────────────────────────
step "Parando infra Docker Compose"

cd "$REPO_ROOT"

if [[ "$REMOVE_VOLUMES" == true ]]; then
  warn "Removendo containers E volumes (postgres_data, redis_data)..."
  docker compose down --volumes
  log "Containers e volumes removidos."
else
  docker compose down
  log "Containers parados. Volumes preservados."
  warn "Para apagar os volumes tambem, rode: ./teardown-local-env.sh --volumes"
fi

# ── Resumo ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Nexus — Ambiente local derrubado                  ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${GREEN}║${NC}  %-30s %s\n" "k3s (namespaces nexus/argocd):" "removidos"
printf "${GREEN}║${NC}  %-30s %s\n" "Docker Compose (containers):"   "parados"
if [[ "$REMOVE_VOLUMES" == true ]]; then
printf "${GREEN}║${NC}  %-30s %s\n" "Volumes Docker:"                "removidos"
else
printf "${GREEN}║${NC}  %-30s %s\n" "Volumes Docker:"                "preservados"
fi
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  k3s e Docker Compose parados (binarios preservados)"
echo -e "${GREEN}║${NC}  Para subir novamente: ./setup-local-env.sh"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
