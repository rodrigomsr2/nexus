#!/usr/bin/env bash
# deploy.sh — atualiza a image tag no values.yaml e faz helm upgrade no k3s
#
# Uso:
#   ./deploy.sh <serviceKey> <tag>
#
# Exemplos:
#   ./deploy.sh ordersService   sha-abc1234
#   ./deploy.sh catalogService  latest
#   ./deploy.sh frontend        sha-def5678
#
# serviceKey deve ser uma das chaves em infra/helm/nexus/values.yaml:
#   ordersService | catalogService | logisticsService | apiGateway | frontend
#
# Dependências: yq (https://github.com/mikefarah/yq), helm, kubectl/k3s

set -euo pipefail

SERVICE_KEY="${1:?Informe o serviceKey (ex: ordersService)}"
TAG="${2:?Informe a tag da imagem (ex: sha-abc1234)}"

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)/.."
VALUES_FILE="${REPO_ROOT}/infra/helm/nexus/values.yaml"
CHART_DIR="${REPO_ROOT}/infra/helm/nexus"
NAMESPACE="nexus"
RELEASE="nexus"

# ── Valida serviceKey ──────────────────────────────────────────────────────
VALID_KEYS="ordersService catalogService logisticsService apiGateway frontend"
if ! echo "$VALID_KEYS" | grep -qw "$SERVICE_KEY"; then
  echo "Erro: serviceKey inválido '$SERVICE_KEY'"
  echo "Valores válidos: $VALID_KEYS"
  exit 1
fi

# ── Atualiza tag no values.yaml ────────────────────────────────────────────
echo ">> Atualizando ${SERVICE_KEY}.image.tag = ${TAG}"
yq e ".${SERVICE_KEY}.image.tag = \"${TAG}\"" -i "$VALUES_FILE"

# ── Helm upgrade --install ─────────────────────────────────────────────────
echo ">> helm upgrade --install ${RELEASE} (namespace: ${NAMESPACE})"
helm upgrade --install "$RELEASE" "$CHART_DIR" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --kubeconfig "${KUBECONFIG:-$HOME/.kube/config}" \
  --wait \
  --timeout 5m

echo ""
echo "Deploy concluido: ${SERVICE_KEY} -> ${TAG}"
