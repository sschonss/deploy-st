# Deploy ST — Fluxo Completo de Deploy

> Projeto didático: Laravel API → Docker → GitHub Actions → Helm → ArgoCD → Kubernetes

Este repositório demonstra um fluxo completo de deploy, do código ao cluster Kubernetes, usando ferramentas padrão da indústria.

## Arquitetura

```
┌──────────┐     ┌────────────────┐     ┌──────────┐     ┌─────────────┐
│Developer │────▶│ GitHub Actions │────▶│  GHCR    │────▶│  ArgoCD     │
│ git push │     │  CI/CD         │     │ (images) │     │  (GitOps)   │
└──────────┘     └────────────────┘     └──────────┘     └──────┬──────┘
                                                                │
                                                    ┌───────────┴───────────┐
                                                    │                       │
                                              ┌─────▼─────┐         ┌──────▼──────┐
                                              │  Staging   │         │ Production  │
                                              │ (auto-sync)│         │(manual sync)│
                                              └───────────┘         └─────────────┘
```

## Pré-requisitos

| Ferramenta | Versão mínima | Instalação |
|------------|---------------|------------|
| Docker | 20+ | [docker.com](https://docs.docker.com/get-docker/) |
| Minikube | 1.30+ | `brew install minikube` |
| kubectl | 1.27+ | `brew install kubectl` |
| Helm | 3.12+ | `brew install helm` |
| PHP | 8.3+ | `brew install php` |
| Composer | 2.5+ | `brew install composer` |
| GitHub CLI | 2.0+ | `brew install gh` |
| act | 0.2+ | `brew install act` |

## Setup Rápido

### 1. Clone o repositório

```bash
git clone https://github.com/sschonss/deploy-st.git
cd deploy-st
```

### 2. Instale as dependências do Laravel

```bash
cd app
composer install
cp .env.example .env
php artisan key:generate
cd ..
```

### 3. Rode os testes localmente

```bash
cd app && php artisan test && cd ..
```

### 4. Suba o Minikube

```bash
./scripts/setup-minikube.sh
```

### 5. Instale o ArgoCD

```bash
./scripts/install-argocd.sh
```

### 6. Configure o /etc/hosts

```bash
MINIKUBE_IP=$(minikube ip)
echo "$MINIKUBE_IP staging.deploy-st.local" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP production.deploy-st.local" | sudo tee -a /etc/hosts
```

### 7. Acesse o ArgoCD

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Abra: https://localhost:8080
# User: admin | Senha: exibida no install-argocd.sh
```

## Entendendo o Fluxo

### CI (Integração Contínua)

Todo push e pull request dispara o pipeline CI:

1. **Testes:** `php artisan test` roda os testes do Laravel
2. **Build Docker:** Valida que as imagens Docker compilam sem erros

Veja: [`.github/workflows/ci.yml`](.github/workflows/ci.yml)

### CD (Entrega Contínua)

Criar uma tag `v*` dispara o pipeline CD:

1. **Build:** Compila imagens Docker (`app` + `web`)
2. **Push:** Publica no GitHub Container Registry (GHCR)
3. **Release:** Cria GitHub Release com changelog automático
4. **Update:** Atualiza `values-staging.yaml` com a nova versão

Veja: [`.github/workflows/cd.yml`](.github/workflows/cd.yml)

### GitOps com ArgoCD

O ArgoCD monitora este repositório e sincroniza com o cluster:

- **Staging:** Auto-sync — qualquer mudança no Helm chart é aplicada automaticamente
- **Production:** Manual sync — requer aprovação explícita no dashboard do ArgoCD

### Rodando CI/CD Localmente

Use o `act` para testar os pipelines sem fazer push:

```bash
# Rodar CI (testes + build)
./scripts/run-ci-local.sh ci

# Simular CD para uma versão
./scripts/run-ci-local.sh cd v1.0.0
```

## Fazendo sua Primeira Release

```bash
# 1. Certifique-se que está na main com tudo commitado
git checkout main
git pull

# 2. Crie a release
./scripts/create-release.sh 1.0.0

# 3. Acompanhe o pipeline
# https://github.com/sschonss/deploy-st/actions

# 4. Verifique o staging
curl http://staging.deploy-st.local/api/version
# {"version":"v1.0.0","app":"deploy-st"}

# 5. Promova para production
# Abra o ArgoCD → deploy-st-production → Sync
```

## Verificando o Deploy

```bash
# Health check
curl http://staging.deploy-st.local/api/health
# {"status":"ok"}

# Versão
curl http://staging.deploy-st.local/api/version
# {"version":"v1.0.0","app":"deploy-st"}

# Info do ambiente
curl http://staging.deploy-st.local/api/status
# {"environment":"staging","debug":true,...}
```

## Estrutura do Projeto

```
deploy-st/
├── app/               # Laravel API (health, version, status)
├── docker/            # Dockerfile multi-target + nginx.conf
├── helm/deploy-st/    # Helm chart (values por ambiente)
├── .github/workflows/ # CI + CD pipelines
├── argocd/            # ArgoCD Application manifests
└── scripts/           # Setup helpers (minikube, argocd, release, act)
```

## Troubleshooting

**Minikube não inicia:**
```bash
minikube delete && minikube start --driver=docker
```

**Pods em CrashLoopBackOff:**
```bash
kubectl logs -n staging deploy/deploy-st-staging --container app
kubectl logs -n staging deploy/deploy-st-staging --container web
```

**ArgoCD não sincroniza:**
```bash
# Verifique o status da Application
kubectl get applications -n argocd
# Force sync
kubectl -n argocd patch application deploy-st-staging --type merge -p '{"operation":{"sync":{}}}'
```

**Ingress não funciona:**
```bash
# Verifique se o addon está habilitado
minikube addons list | grep ingress
# Verifique o /etc/hosts
cat /etc/hosts | grep deploy-st
```
