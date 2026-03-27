# Runbook — k3s e ArgoCD

Problemas encontrados durante o bootstrap do ambiente local (k3s + ArgoCD).

---

## 1. CRD do ArgoCD grande demais para `kubectl apply` clássico

### Problema

```
The CustomResourceDefinition "applicationsets.argoproj.io" is invalid:
metadata.annotations: Too long: may not be more than 262144 bytes
```

O `kubectl apply` tradicional (client-side apply) armazena o manifesto inteiro na annotation `kubectl.kubernetes.io/last-applied-configuration`. O CRD `applicationsets.argoproj.io` excede o limite de 262 KB.

### Solução

Usar **Server-Side Apply** (`--server-side`):

```bash
kubectl apply -n argocd --server-side \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

No server-side apply, o API server rastreia a ownership dos campos internamente via `managedFields`, sem guardar o manifesto completo em annotation.

---

## 2. Conflito de ownership ao trocar de client-side para server-side apply

### Problema

```
Apply failed with 1 conflict: conflict with "kubectl-client-side-apply" using apps/v1:
.spec.template.spec.containers[name="argocd-applicationset-controller"].env[name="NAMESPACE"].valueFrom.fieldRef
```

A primeira execução (que falhou) já havia aplicado parte dos recursos com client-side apply. Ao reaplicar com server-side apply, o Kubernetes detectou campos gerenciados pelo manager `kubectl-client-side-apply` e recusou a transferência de ownership.

### Solução

Adicionar `--force-conflicts` para forçar a transferência de ownership:

```bash
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Seguro neste caso porque somos os únicos gerenciando o ArgoCD neste cluster. O `setup-local-env.sh` usa `--server-side --force-conflicts` por padrão.

---

## 3. `kubectl` usando kubeconfig errado após instalar o k3s

### Problema

Comandos `kubectl` retornavam:

```
Error from server (NotFound): namespaces "argocd" not found
```

mesmo o namespace tendo sido criado. Causa: o script exportava `KUBECONFIG=/etc/rancher/k3s/k3s.yaml` apenas para seu próprio processo. O terminal continuava usando `~/.kube/config`, apontando para outro cluster.

**Agravante:** uma versão anterior do script fez `sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config`, sobrescrevendo configurações de outros clusters.

### Solução — merge seguro no script

```bash
cp ~/.kube/config ~/.kube/config.bak
KUBECONFIG=~/.kube/config:/etc/rancher/k3s/k3s.yaml \
  kubectl config view --flatten > ~/.kube/config.merged
mv ~/.kube/config.merged ~/.kube/config
```

### Para a sessão atual (se necessário)

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

**Lição:** nunca sobrescrever `~/.kube/config` diretamente. O arquivo pode conter contextos de múltiplos clusters. Sempre fazer merge.

---

## 4. Warnings `memcache.go: couldn't get resource list for metrics.k8s.io/v1beta1`

### Problema

```
E0325 09:37:29 memcache.go:287] couldn't get resource list for metrics.k8s.io/v1beta1:
the server is currently unable to handle the request
```

Todo comando `kubectl` exibia esse warning.

### Causa

O `kubectl` faz discovery de todas as APIs disponíveis antes de executar. O k3s instala o `metrics-server` por padrão, mas ele demora alguns minutos para inicializar. Durante esse período, a API está registrada mas não responde.

### Impacto

Nenhum — são warnings, não erros. O comando executa normalmente.

### Quando desaparecem

Automaticamente, após o metrics-server inicializar (~2-5 minutos após instalar o k3s):

```bash
kubectl get deployment metrics-server -n kube-system
```

---

## 5. `v1 Endpoints` depreciado no k3s v1.33+

### Problema

```
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
```

O script criava objetos `Endpoints` (API legada) para apontar serviços do k3s para os containers Docker Compose no host.

### Solução — migrar para `EndpointSlice`

```yaml
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: redis
  namespace: nexus
  labels:
    kubernetes.io/service-name: redis   # obrigatório — vincula ao Service
addressType: IPv4
endpoints:
  - addresses:
      - "<HOST_IP>"
ports:
  - port: 6379
    protocol: TCP
```

**Diferença importante:** no `EndpointSlice`, a label `kubernetes.io/service-name` é obrigatória para vincular ao Service. No `v1 Endpoints`, o vínculo era feito pelo nome do objeto (mesmo nome do Service). O `setup-local-env.sh` já usa `EndpointSlice`.

---

## 6. Namespace preso em `Terminating` durante o teardown

### Problema

```
namespace "nexus" deleted
error: timed out waiting for the condition on namespaces/nexus
```

O namespace ficou indefinidamente em `Terminating`.

### Causa

Namespaces só são removidos após todos os recursos internos serem deletados. O ArgoCD adiciona finalizers nos recursos que gerencia. Se o namespace for deletado antes do ArgoCD remover seus finalizers, eles ficam órfãos — sem controller para resolvê-los.

### Solução manual

```bash
kubectl get namespace nexus -o json \
  | python3 -c "import sys,json; d=json.load(sys.stdin); d['spec']['finalizers']=[]; print(json.dumps(d))" \
  | kubectl replace --raw /api/v1/namespaces/nexus/finalize -f -
```

### Solução no script (`teardown-local-env.sh`)

O script trata o timeout como sinal de namespace preso e executa o desbloqueio automaticamente:

```bash
kubectl delete namespace "$ns" --timeout=60s || force_delete_namespace "$ns"
```

**Por que `--raw /finalize` funciona:** o endpoint `/finalize` é uma subresource especial que permite atualizar apenas `spec.finalizers`, sem passar pelo webhook de validação normal.

**Lição:** a ordem de remoção importa. Remover a `Application` do ArgoCD **antes** de deletar o namespace dá tempo ao ArgoCD de limpar seus finalizers graciosamente. O `teardown-local-env.sh` já faz isso: remove a Application → desativa syncPolicy → deleta o namespace.

---

## Contexto do ambiente

| Componente | Versão |
|-----------|--------|
| OS | Ubuntu (Linux 6.8.0) |
| k3s | v1.34.5+k3s1 |
| Helm | v4.1.1 |
| ArgoCD | stable (manifesto oficial) |
| Docker | 29.3.0 |
