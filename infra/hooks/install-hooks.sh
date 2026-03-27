#!/usr/bin/env bash
# infra/hooks/install-hooks.sh — instala os git hooks do projeto Nexus
#
# Uso:
#   chmod +x infra/hooks/install-hooks.sh
#   ./infra/hooks/install-hooks.sh
#
# O que faz:
#   Copia todos os hooks de infra/hooks/ para .git/hooks/, preservando permissões.
#   Hooks existentes são substituídos após confirmação.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS_SRC="${REPO_ROOT}/infra/hooks"
HOOKS_DST="${REPO_ROOT}/.git/hooks"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
log()  { echo -e "${GREEN}[hooks]${NC} $*"; }
warn() { echo -e "${YELLOW}[ warn]${NC} $*"; }

if [[ ! -d "$HOOKS_DST" ]]; then
  echo "Erro: .git/hooks não encontrado. Execute dentro de um repositório Git."
  exit 1
fi

HOOKS=$(find "$HOOKS_SRC" -maxdepth 1 -type f ! -name "*.sh" ! -name "*.md")

if [[ -z "$HOOKS" ]]; then
  warn "Nenhum hook encontrado em infra/hooks/."
  exit 0
fi

echo ""
echo -e "${BOLD}Hooks a instalar:${NC}"
echo "$HOOKS" | sed "s|${HOOKS_SRC}/|  |"
echo ""

for HOOK_SRC in $HOOKS; do
  HOOK_NAME="$(basename "$HOOK_SRC")"
  HOOK_DST="${HOOKS_DST}/${HOOK_NAME}"

  if [[ -f "$HOOK_DST" ]]; then
    warn "Hook '${HOOK_NAME}' já existe em .git/hooks/. Substituindo..."
  fi

  cp "$HOOK_SRC" "$HOOK_DST"
  chmod +x "$HOOK_DST"
  log "Hook '${HOOK_NAME}' instalado."
done

echo ""
log "Todos os hooks instalados em .git/hooks/."
echo -e "  Para pular um hook pontualmente: ${BOLD}git commit --no-verify${NC}"
echo ""
