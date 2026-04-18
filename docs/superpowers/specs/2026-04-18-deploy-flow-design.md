# Deploy Flow — Laravel + GitHub Actions + ArgoCD + Minikube

**Data:** 2026-04-18  
**Objetivo:** Criar um fluxo completo de deploy didático para público intermediário (sabe Docker/Git, nunca montou pipeline completo).  
**Repositório:** Monorepo — app, infra e CI/CD juntos para facilitar estudo e apresentação.

---

## 1. Visão Geral do Fluxo

```
Developer → git push → GitHub Actions (CI) → Testes + Build validação
                                              
git tag v1.x.x → GitHub Actions (CD) → Build Docker Image
                                      → Push to GHCR
                                      → Create GitHub Release
                                      → Update values-staging.yaml
                                      
ArgoCD (Minikube) → Detecta mudança → Deploy staging (auto-sync)
                                    → Deploy production (manual sync)
```

### Fluxo Detalhado

1. Dev faz push para branch → CI roda testes e valida build Docker
2. Dev cria tag `v1.x.x` e faz push → CD pipeline é ativado
3. CD builda imagem Docker, publica no GHCR, cria GitHub Release
4. CD atualiza `values-staging.yaml` com nova tag da imagem (commit automático)
5. ArgoCD detecta mudança no repo → deploya automaticamente em staging
6. Para production: aprovação manual no ArgoCD UI → sync e deploy

---

## 2. App Laravel — API REST Mínima

API REST com 3 endpoints, sem banco de dados. O foco é o fluxo de deploy, não o app.

### Endpoints

| Método | Rota | Descrição | Uso no fluxo |
|--------|------|-----------|--------------|
| GET | `/api/health` | Retorna `{"status": "ok"}` | Liveness/readiness probes do K8s |
| GET | `/api/version` | Retorna versão do app | Validar que a release correta está rodando |
| GET | `/api/status` | Retorna info do ambiente | Diferenciar staging de production |

### Stack

- PHP 8.3
- Laravel (última versão estável)
- Sem banco de dados
- Sem autenticação

---

## 3. Estrutura do Repositório

```
deploy-st/
├── app/                          # Laravel API (raiz do projeto Laravel)
│   ├── routes/api.php
│   ├── app/Http/Controllers/
│   ├── tests/
│   └── ...
├── docker/
│   ├── Dockerfile                # Multi-stage build (PHP-FPM + Nginx)
│   └── nginx.conf                # Config Nginx para servir Laravel
├── helm/
│   └── deploy-st/
│       ├── Chart.yaml
│       ├── values.yaml           # Valores default
│       ├── values-staging.yaml   # Override para staging
│       ├── values-production.yaml # Override para production
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           ├── configmap.yaml
│           ├── secret.yaml
│           ├── hpa.yaml
│           └── pdb.yaml
├── .github/
│   └── workflows/
│       ├── ci.yml                # Testes + build validação em todo push
│       └── cd.yml                # Build, push, release em tag v*
├── argocd/
│   ├── staging-app.yaml          # ArgoCD Application para staging
│   └── production-app.yaml       # ArgoCD Application para production
├── scripts/
│   ├── setup-minikube.sh         # Sobe cluster Minikube
│   ├── install-argocd.sh         # Instala ArgoCD no cluster
│   └── create-release.sh        # Helper: cria tag + push
└── README.md                     # Guia passo-a-passo didático
```

---

## 4. Docker — Multi-Stage Build

### Dockerfile (multi-target)

Um Dockerfile com múltiplos targets para buildar duas imagens do mesmo código:

- **Target `app`:** PHP-FPM 8.3 com dependências Composer e código Laravel
- **Target `web`:** Nginx configurado como reverse proxy para PHP-FPM

Build:
```bash
docker build --target app -t ghcr.io/sschonss/deploy-st-app:v1.0.0 .
docker build --target web -t ghcr.io/sschonss/deploy-st-web:v1.0.0 .
```

### Estratégia no Pod

PHP-FPM (`app`) e Nginx (`web`) rodam como dois containers no mesmo pod. Nginx faz proxy para PHP-FPM via `localhost:9000`. O código Laravel é copiado para ambas as imagens no build.

### Imagem publicada em

`ghcr.io/sschonss/deploy-st:<tag>`

---

## 5. Pipeline CI/CD — GitHub Actions

### CI (`ci.yml`) — Trigger: push em qualquer branch, pull_request

1. Checkout código
2. Setup PHP 8.3 + Composer install (com cache)
3. Roda `php artisan test`
4. Build Docker image (validação, sem push)
5. Linting com PHP-CS-Fixer

### CD (`cd.yml`) — Trigger: push de tag `v*`

1. Checkout código
2. Login no GHCR (`ghcr.io`)
3. Build Docker image multi-stage
4. Tag image: `ghcr.io/sschonss/deploy-st:v1.x.x` + `latest`
5. Push image para GHCR
6. Cria GitHub Release com changelog automático (baseado nos commits desde a última tag)
7. Atualiza `helm/deploy-st/values-staging.yaml` com nova `image.tag`
8. Commit e push da atualização (trigger para ArgoCD)

---

## 6. Sistema de Releases

### Fluxo

```bash
# Dev cria e publica a tag
git tag v1.0.0
git push origin v1.0.0

# OU usa o helper script
./scripts/create-release.sh 1.0.0
```

### Convenções

- Tags seguem semver: `v1.0.0`, `v1.1.0`, `v2.0.0`
- GitHub Release criado automaticamente pelo CD pipeline
- Changelog gerado a partir dos commits entre tags
- Release notes incluem: commits, imagem Docker, diff link

---

## 7. Kubernetes — Helm Charts

### Recursos por ambiente

| Recurso | Staging | Production |
|---------|---------|------------|
| Deployment | 1 réplica | 2 réplicas (base) |
| HPA | Desabilitado | 2-5 réplicas, target CPU 70% |
| PDB | Desabilitado | minAvailable: 1 |
| Resources requests | 100m CPU, 128Mi RAM | 250m CPU, 256Mi RAM |
| Resources limits | 250m CPU, 256Mi RAM | 500m CPU, 512Mi RAM |
| APP_DEBUG | true | false |
| LOG_LEVEL | debug | warning |

### Probes

- **Liveness:** `GET /api/health` — reinicia pod se falhar
- **Readiness:** `GET /api/health` — remove do service se falhar
- **Startup:** `GET /api/health` com `initialDelaySeconds: 10` — espera app iniciar

### Ingress

- Staging: `staging.deploy-st.local`
- Production: `production.deploy-st.local`
- Requer addon `ingress` do Minikube + entrada no `/etc/hosts`

### Secrets

- Simulados com Kubernetes Secrets (valores de exemplo para estudo)
- Incluem: APP_KEY, API_KEY (valores dummy)

---

## 8. ArgoCD — GitOps Local

### Instalação

- Instalado dentro do Minikube via manifests oficiais
- Acesso ao dashboard via `kubectl port-forward svc/argocd-server -n argocd 8080:443`

### Applications

**Staging (`argocd/staging-app.yaml`):**
- Source: repositório GitHub, path `helm/deploy-st`
- Values file: `values-staging.yaml`
- Sync policy: auto-sync + auto-prune + self-heal
- Namespace: `staging`

**Production (`argocd/production-app.yaml`):**
- Source: repositório GitHub, path `helm/deploy-st`
- Values file: `values-production.yaml`
- Sync policy: manual (requer sync explícito no UI)
- Namespace: `production`

### Workflow no ArgoCD

1. CD pipeline atualiza `values-staging.yaml` → ArgoCD detecta → auto-deploy staging
2. Validação em staging
3. Operador atualiza `values-production.yaml` (image.tag) manualmente
4. ArgoCD mostra diff no dashboard → operador confirma sync → deploy production

---

## 9. Scripts de Setup

### `setup-minikube.sh`
- Inicia Minikube com driver Docker
- Habilita addons: ingress, metrics-server
- Cria namespaces: staging, production, argocd

### `install-argocd.sh`
- Aplica manifests do ArgoCD no namespace argocd
- Espera pods ficarem ready
- Extrai senha admin inicial
- Aplica Applications (staging + production)
- Informa URL de acesso

### `create-release.sh`
- Recebe versão como argumento
- Cria tag git
- Faz push da tag (trigger CD pipeline)

---

## 10. README — Guia Didático

O README serve como guia passo-a-passo para quem clonar o repo. Estrutura:

1. **Pré-requisitos:** Docker, Minikube, kubectl, Helm, GitHub CLI
2. **Setup rápido:** clone, setup Minikube, instala ArgoCD
3. **Entendendo o fluxo:** diagrama + explicação de cada peça
4. **Fazendo sua primeira release:** passo-a-passo com git tag
5. **Verificando o deploy:** como acessar staging e production
6. **Troubleshooting:** problemas comuns e soluções

---

## Decisões de Design

| Decisão | Escolha | Justificativa |
|---------|---------|---------------|
| Estrutura | Monorepo | Didático — tudo junto facilita estudo |
| CI/CD | GitHub Actions | Mais comum no mercado |
| Container Registry | GHCR | Integrado com GitHub, sem setup extra |
| K8s local | Minikube | Simples, estável, bem documentado |
| Package manager K8s | Helm | Padrão de mercado, funciona bem com ArgoCD |
| GitOps | ArgoCD | Referência em GitOps, UI visual para demonstração |
| Releases | Git tags + GitHub Releases | Padrão da indústria, fácil de entender |
| Ambientes | staging + production (local) | Suficiente para demonstrar o fluxo sem custo |
