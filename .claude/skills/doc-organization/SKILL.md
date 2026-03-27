---
name: doc-organization
description: |
  Organiza e estrutura a documentação de projetos de software seguindo um sistema de camadas por tipo de conhecimento. Use esta skill sempre que o usuário pedir para organizar, estruturar, criar ou reorganizar a documentação de um projeto — incluindo pedidos como "como devo documentar meu projeto", "cria a estrutura de docs do projeto", "organiza minha documentação", "quero um sistema de documentação", ou quando o usuário colar arquivos de documentação existentes e pedir ajuda para reorganizá-los. Também use quando o usuário mencionar ADRs, runbooks, CLAUDE.md, ou quando estiver criando um novo projeto e precisar definir onde cada tipo de conhecimento vai viver.
---

# Skill — Organização de Documentação de Projetos

Esta skill define como estruturar a documentação de um projeto de software de forma que o conhecimento seja fácil de encontrar, não se duplique e cresça sem virar bagunça.

---

## Princípio central

Conhecimento tem naturezas diferentes. Cada natureza tem um lugar certo. Misturar naturezas no mesmo arquivo é a principal causa de documentação que ninguém lê.

| Natureza | Pergunta que responde | Onde vive |
|----------|----------------------|-----------|
| Decisões arquiteturais | Por que foi feito assim? | `docs/adr/` |
| Procedimentos operacionais | Como faço X? | `docs/runbook/` |
| Problemas conhecidos e gotchas | O que pode dar errado? | `docs/runbook/` (junto ao tema) |
| Regras de negócio | O que o sistema faz? | `<serviço>/docs/business-rules.md` |
| Visão geral e onboarding | O que é o projeto? | `README.md` |
| Contexto para IA | O que o agente precisa saber? | `CLAUDE.md` (por nível) |
| Informações pessoais/locais | Paths, IPs, credenciais locais | `CLAUDE.local.md` (no .gitignore) |

---

## Estrutura canônica

```
projeto/
├── README.md                  # Visão geral + início rápido — público: qualquer pessoa nova
├── CLAUDE.md                  # Só índice — aponta para README e docs/
├── CLAUDE.local.md            # Informações locais/pessoais — NÃO versionar (.gitignore)
├── RUNNER.md                  # Runner de CI/CD (se houver self-hosted runner)
│
├── docs/
│   ├── adr/                   # Decisões arquiteturais
│   │   └── ADR-NNN-titulo-da-decisao.md
│   ├── runbook/               # Procedimentos operacionais + troubleshooting por tema
│   │   └── <tema>.md
│   └── security.md            # Segurança do repositório e CI/CD
│
└── <serviço>/
    ├── CLAUDE.md              # Contexto do serviço para IA — aponta para docs/
    └── docs/
        ├── business-rules.md  # Regras de negócio do bounded context
        └── <topico>.md        # Documentos específicos do serviço (ex: pricing-engine.md)
```

---

## Regras de ouro

### 1. Zero duplicação
Cada informação existe em exatamente um lugar. `README.md` e `CLAUDE.md` **não** duplicam conteúdo — o `CLAUDE.md` é índice, o `README.md` é conteúdo.

### 2. CLAUDE.md é só índice
O `CLAUDE.md` raiz contém apenas uma tabela "onde encontrar o quê" e apontadores para os arquivos corretos. Nunca copiar regras de negócio ou configurações para dentro dele.

### 3. Runbook = procedimento + troubleshooting juntos por tema
Não separar "como fazer" de "problemas encontrados" em pastas diferentes. Se o tema é Kafka, tudo sobre Kafka vai em `docs/runbook/kafka.md`: setup, problemas, soluções, gotchas.

### 4. ADRs com alternativas rejeitadas
O valor de um ADR está no que foi **descartado** e por quê. Sem essa seção, o ADR é só um registro de decisão — não um guia para não repetir os mesmos erros.

### 5. Informações pessoais nunca versionadas
Paths de máquina, IPs locais, credenciais de desenvolvimento — tudo em `CLAUDE.local.md`, que vai no `.gitignore`. O `RUNNER.md` e os runbooks fazem referência a esse arquivo mas não contêm os dados.

### 6. Scripts em `infra/` com REPO_ROOT corrigido
Se scripts de setup/teardown/deploy forem movidos para `infra/`, corrigir:
```bash
# De:
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
# Para:
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
```

---

## Template — README.md

O README responde: o que é, como rodar, onde tem mais.

```markdown
# Nome do Projeto

Descrição em uma linha.

## Stack
(tabela)

## Estrutura do repositório
(árvore simplificada com comentários)

## Início rápido
(pré-requisitos, comandos mínimos para rodar)

## Testes
(comandos)

## Documentação
(tabela: documento → descrição, com links)

## Convenções
(lista de convenções de código do projeto)

## ADRs vigentes
(lista com links para docs/adr/)
```

---

## Template — ADR

```markdown
# ADR-NNN — Título da decisão

**Status:** Aceito | Deprecado | Substituído por ADR-NNN
**Data:** YYYY-MM-DD

## Contexto
Qual problema estávamos resolvendo.

## Decisão
O que escolhemos e como funciona.

## Consequências aceitas
Trade-offs reais que aceitamos com essa decisão.

## Alternativas rejeitadas
O que consideramos e por que descartamos. (Seção mais valiosa do ADR.)
```

---

## Template — Runbook (entrada de problema)

Cada problema documentado num runbook deve ter:

```markdown
## N. Título do problema

### Sintoma
O que aparece no terminal/log. Incluir mensagem de erro exata.

### Causa
Por que acontece. Mecanismo técnico.

### Tentativas que não funcionaram (se houver)
O que foi tentado antes e por que não resolveu.

### Solução
Comandos exatos para resolver.

### Lição / quando usar
Generalização para evitar o problema no futuro.
```

---

## Template — CLAUDE.md (raiz)

```markdown
# Nome do Projeto — Índice para IA

Descrição em uma linha.

> Para visão geral, stack e início rápido: leia o `README.md`.

## Onde encontrar cada tipo de conhecimento

| Tipo | Onde |
|------|------|
| Stack, estrutura e início rápido | `README.md` |
| Decisões arquiteturais (ADRs) | `docs/adr/` |
| Setup e operação do ambiente | `docs/runbook/local-env.md` |
| ... | ... |

## Comunicação entre serviços (se microsserviços)
(tabela de tópicos/eventos)

## ADRs vigentes
(lista com links)
```

---

## Template — CLAUDE.md (por serviço)

```markdown
# nome-do-serviço — Contexto para IA

Bounded context de X. Faz Y.

> Regras de negócio: `<serviço>/docs/business-rules.md`
> Tópicos específicos: `<serviço>/docs/<topico>.md`

## Responsabilidades
(lista)

## Pacote base
(árvore de pacotes com comentários)

## Notas de implementação
(bullets com decisões táticas, padrões obrigatórios, armadilhas conhecidas)
```

---

## Checklist ao criar documentação de um projeto novo

- [ ] `README.md` cobre: o que é, stack, estrutura, início rápido, testes, links para docs
- [ ] `CLAUDE.md` raiz é só índice — nenhuma regra de negócio dentro
- [ ] `CLAUDE.local.md` existe e está no `.gitignore`
- [ ] `docs/adr/` tem pelo menos os ADRs principais, com seção "alternativas rejeitadas"
- [ ] `docs/runbook/` tem um arquivo por tema operacional relevante
- [ ] Cada serviço tem `CLAUDE.md` + `docs/business-rules.md`
- [ ] Nenhuma informação existe em dois lugares ao mesmo tempo
- [ ] Scripts em `infra/` têm `REPO_ROOT` com `..` se necessário

---

## Checklist ao reorganizar documentação existente

1. **Inventariar** — listar todos os arquivos de doc existentes e classificar por natureza
2. **Identificar duplicações** — onde o mesmo conteúdo aparece em mais de um lugar
3. **Identificar lacunas** — ADRs mencionados mas não criados, runbooks que deveriam existir
4. **Mapear destino** — para cada arquivo atual, decidir onde vai na nova estrutura
5. **Criar estrutura** — pastas `docs/adr/`, `docs/runbook/`, `<serviço>/docs/`
6. **Migrar conteúdo** — mover sem duplicar, ajustar referências cruzadas
7. **Atualizar CLAUDE.md** — tabela de índice refletindo a nova estrutura
8. **Atualizar README.md** — seção "Documentação" com links corretos
