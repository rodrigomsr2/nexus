# Runbook — Kafka

Problemas encontrados ao subir o Kafka no ambiente local (Docker Compose + k3s).

---

## 1. Containers Docker não se comunicam após instalar o k3s

### Sintoma

Kafka com `Exited (1)` imediatamente após iniciar:

```
ERROR Timed out waiting for connection to Zookeeper server [zookeeper:2181]
java.net.NoRouteToHostException: No route to host
```

Zookeeper estava saudável. O bridge Docker estava `UP`. Mesmo assim o Kafka não alcançava o Zookeeper.

### Causa raiz

O k3s ativa `net.bridge.bridge-nf-call-iptables=1` ao instalar o Flannel/kube-router. Isso faz todo tráfego entre containers Docker passar pelo iptables. O kube-router define a política padrão da chain `FORWARD` como `DROP` para isolar pods Kubernetes.

Resultado: pacotes entre `nexus-kafka` e `nexus-zookeeper` — no mesmo bridge Docker — passam pelo iptables e são dropados.

### Tentativas que não funcionaram

**`iptables -P FORWARD ACCEPT`** — funciona, mas abre o forward globalmente. Inadequado para máquina com acesso à internet.

**Regras por interface bridge:**
```bash
sudo iptables -I FORWARD -i br-+ -o br-+ -j ACCEPT
```
Não funciona porque, com `bridge-nf-call-iptables=1`, os campos `-i` e `-o` são preenchidos com interfaces **veth** individuais dos containers, não com o nome do bridge. As regras nunca fazem match.

### Solução — `--physdev-is-bridged`

```bash
sudo iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT
sudo apt install iptables-persistent -y
sudo netfilter-persistent save
```

O módulo `physdev` com `--physdev-is-bridged` faz match especificamente em pacotes encaminhados através de um bridge Linux. Tráfego da internet chega pela interface física (`eth0`), que não é porta de bridge — não é afetado.

| Tráfego | É bridge port? | Match na regra? |
|---------|---------------|----------------|
| Container → Container (Docker) | Sim (veth) | **Sim (ACCEPT)** |
| Internet → Host | Não (eth0) | Não |
| k3s pod → pod (Flannel) | Não (flannel.1/cni0) | Não |

O `iptables-persistent` salva as regras em `/etc/iptables/rules.v4` e as restaura no boot. O `setup-local-env.sh` aplica essa regra automaticamente.

---

## 2. Pods k3s não conseguem conectar ao Kafka

### Problema

Dois obstáculos para pods k3s acessarem o Kafka no Docker Compose:

1. **DNS**: `kafka` não resolve dentro do k3s
2. **Advertised listeners**: mesmo que o pod conecte, o Kafka responde com o endereço que ele quer ser alcançado. Se esse endereço não for alcançável de dentro do pod, a conexão falha na segunda fase.

### Como o Kafka anuncia endereços (protocolo)

1. **Bootstrap**: cliente conecta em qualquer broker para descobrir a topologia
2. **Fetch metadata**: broker responde com os `ADVERTISED_LISTENERS` — endereços pelos quais quer ser reconectado

Se `ADVERTISED_LISTENERS` retornar `localhost:9092`, um pod que conectou via `kafka:9092` vai tentar reconectar em `localhost:9092` — que não existe dentro do pod.

### Solução — terceiro listener `PLAINTEXT_K8S`

No `docker-compose.yml`:

```yaml
KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:29092,PLAINTEXT_HOST://0.0.0.0:9092,PLAINTEXT_K8S://0.0.0.0:9093
KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092,PLAINTEXT_K8S://${HOST_IP:-localhost}:9093
KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT,PLAINTEXT_K8S:PLAINTEXT
```

| Listener | Porta | Usado por | Advertise |
|----------|-------|-----------|-----------|
| `PLAINTEXT` | 29092 | Comunicação interna Docker Compose | `kafka:29092` |
| `PLAINTEXT_HOST` | 9092 | Acesso da máquina host | `localhost:9092` |
| `PLAINTEXT_K8S` | 9093 | Pods do k3s | `HOST_IP:9093` |

No k3s, um Service `kafka` no namespace `nexus` aponta para `HOST_IP:9093`. Quando um pod conecta em `kafka:9092` (ClusterIP do Service), é redirecionado para `HOST_IP:9093`. O Kafka responde com `HOST_IP:9093` como endereço de reconexão — alcançável pelo pod.

O `${HOST_IP}` é gravado no `.env` pelo `setup-local-env.sh` antes do `docker compose up`.

---

## 3. Kafka falha na inicialização antes do Zookeeper estar pronto

### Sintoma

Mesmo após resolver o problema de rede, o Kafka ocasionalmente falha na primeira tentativa se levantado junto com o Zookeeper.

### Causa

`depends_on: [zookeeper]` garante que o **container** foi criado, não que o Zookeeper está **aceitando conexões** na porta 2181.

### Solução

Subir o Zookeeper primeiro:

```bash
docker compose up -d zookeeper
sleep 10
docker compose up -d kafka
```

Alternativa: subir tudo de uma vez e confiar no retry interno do Kafka (~30 segundos). Se o Zookeeper subir dentro dessa janela, o Kafka se recupera automaticamente.

O `setup-local-env.sh` aguarda explicitamente antes de prosseguir.

---

## Contexto do ambiente

| Componente | Versão |
|-----------|--------|
| Docker | 29.3.0 |
| k3s | v1.34.5+k3s1 (Flannel + kube-router) |
| Kafka | confluentinc/cp-kafka:7.5.0 |
| Zookeeper | confluentinc/cp-zookeeper:7.5.0 |
| OS | Ubuntu (Linux 6.8.0) |
