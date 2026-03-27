# Runbook — Ambiente Local

Guia operacional completo para subir, operar e derrubar o ambiente de desenvolvimento do Nexus.

O ambiente local combina **Docker Compose** (infra: PostgreSQL, Redis, Kafka, Keycloak) com **k3s** (Kubernetes local) e **ArgoCD** (GitOps).

---

## Scripts disponíveis

| Script | O que faz |
|--------|-----------|
| `setup-local-env.sh` | Instala dependências, sobe infra Docker Compose, configura k3s e instala ArgoCD |
| `teardown-local-env.sh` | Derruba tudo (k3s, ArgoCD, Docker Compose). Preserva volumes por padrão. |
| `deploy.sh <serviceKey> <tag>` | Atualiza a image tag no `values.yaml` e faz `helm upgrade` no k3s |

---

## Git Hooks

O projeto inclui hooks Git que auxiliam na manutenção da documentação. Instale uma vez após clonar o repositório:

```bash
chmod +x infra/hooks/install-hooks.sh
./infra/hooks/install-hooks.sh
```

### Hooks disponíveis

| Hook | Descrição |
|------|-----------|
| `pre-commit` | Pergunta ao desenvolvedor se a alteração requer atualização de documentação |

### Pular pontualmente

```bash
git commit --no-verify -m "..."
```

Use com critério — apenas para commits que genuinamente não afetam documentação (ex: fixup, typo em código).

---

## Setup

### Pré-requisitos

- Docker 24+ e Docker Compose v2 instalados
- Usuário com acesso `sudo` (necessário para instalar k3s, Helm, yq)

### Executar

```bash
chmod +x setup-local-env.sh
./setup-local-env.sh
```

### O que o script faz (em ordem)

1. Verifica/instala dependências: k3s, Helm, yq
2. Detecta o IP do host e grava `.env` para o Docker Compose
3. Corrige regras iptables para comunicação entre containers Docker e k3s (ver `docs/runbook/kafka.md` para contexto)
4. Faz merge do kubeconfig do k3s em `~/.kube/config` (preserva contextos existentes, cria backup)
5. Sobe a infra via Docker Compose: PostgreSQL, Redis, Zookeeper, Kafka, Keycloak, Kafka UI
6. Aguarda PostgreSQL ficar saudável
7. Cria namespace `nexus` e secrets no k3s
8. Cria Services externos no k3s apontando para os containers Docker Compose
9. Instala ArgoCD e aguarda ficar pronto
10. Aplica o ArgoCD Application (`infra/k8s/argocd/nexus-app.yaml`)
11. Exibe resumo de acesso com URLs e senha inicial do ArgoCD

### Serviços após o setup

| Serviço | URL |
|---------|-----|
| ArgoCD UI | https://HOST_IP:30443 (admin / senha exibida no resumo) |
| API Gateway (k3s) | http://HOST_IP:30080 |
| Kafka UI | http://HOST_IP:8090 |
| Keycloak | http://HOST_IP:8180 (admin/admin) |

---

## Teardown

```bash
# Para tudo, preserva volumes Docker (PostgreSQL, Redis)
./teardown-local-env.sh

# Para tudo E apaga volumes
./teardown-local-env.sh --volumes
```

### O que o script faz (em ordem)

1. Remove a ArgoCD Application `nexus` (desativa syncPolicy antes para evitar recriação)
2. Deleta namespace `nexus` (com tratamento automático de namespace preso em Terminating)
3. Deleta namespace `argocd` e CRDs do ArgoCD
4. Para o k3s
5. Para containers Docker Compose (e volumes se `--volumes`)

### O que o script NÃO faz (por segurança)

- Não desinstala k3s, Helm ou yq
- Não apaga volumes Docker (a menos que `--volumes`)
- Não remove o kubeconfig de `~/.kube/config`

Para subir novamente: `./setup-local-env.sh`

---

## Deploy

```bash
./deploy.sh <serviceKey> <tag>

# Exemplos:
./deploy.sh ordersService   sha-abc1234
./deploy.sh catalogService  latest
./deploy.sh frontend        sha-def5678
```

### serviceKeys válidos

`ordersService` | `catalogService` | `logisticsService` | `apiGateway` | `frontend`

### O que o script faz

1. Valida o `serviceKey`
2. Atualiza `.image.tag` no `infra/helm/nexus/values.yaml` via `yq`
3. Executa `helm upgrade --install` no namespace `nexus`

### Dependências

- `yq` v4+ (instalado pelo `setup-local-env.sh`)
- `helm` (instalado pelo `setup-local-env.sh`)
- `kubectl` com kubeconfig configurado (`~/.kube/config`)

---

## Fluxo GitOps completo

```
Push de código
  → GitHub Actions builda a imagem + push para GHCR
  → ./deploy.sh <service> <tag>  atualiza values.yaml + push
  → ArgoCD detecta mudança no Git e sincroniza automaticamente
```

### Forçar sync manual no ArgoCD

```bash
kubectl -n argocd get app nexus
kubectl -n argocd patch app nexus -p '{"operation":{"sync":{}}}' --type merge
```

---

## Variáveis de ambiente

O arquivo `.env` é gerado automaticamente pelo `setup-local-env.sh` com o IP do host detectado. Nunca editar manualmente.

Para configurações dos serviços, ver as seções `environment:` no `docker-compose.yml` ou o arquivo `.env.example`.

---

## Contexto do ambiente

| Componente | Versão |
|-----------|--------|
| OS | Ubuntu (Linux 6.8.0) |
| Docker | 29.3.0 |
| k3s | v1.34.5+k3s1 |
| Helm | v4.1.1 |
| ArgoCD | stable (manifesto oficial) |
