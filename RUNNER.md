# GitHub Actions — Self-hosted Runner

Documentação do runner local configurado para o projeto Nexus.

## Localização

| Item | Caminho |
|------|---------|
| Diretório do runner | ver `CLAUDE.local.md` |
| Work folder | ver `CLAUDE.local.md` |
| Projeto | ver `CLAUDE.local.md` |

## Configuração

| Item | Valor |
|------|-------|
| Runner group | `Default` |
| Nome do runner | `local` |
| Labels | `self-hosted`, `Linux`, `X64`, `local`, `nexus` |
| Sistema operacional | Ubuntu (Linux x64) |

## Uso nos workflows

Para direcionar um job para este runner:

```yaml
runs-on: [self-hosted, local, nexus]
```

## Gerenciamento do serviço

O runner está instalado como serviço systemd e sobe automaticamente com a máquina.

```bash
# Verificar status
sudo ~/actions-runner/svc.sh status

# Iniciar
sudo ~/actions-runner/svc.sh start

# Parar
sudo ~/actions-runner/svc.sh stop
```

## Observação de segurança

Este runner **não é utilizado em CI** por segurança — repositório público expõe o runner a workflows de forks maliciosos. O CI usa runners do GitHub (`ubuntu-latest`). O runner local é reservado para tarefas de deploy manual via script.

Para regras de segurança do repositório e permissões de Actions, veja `docs/security.md`.
