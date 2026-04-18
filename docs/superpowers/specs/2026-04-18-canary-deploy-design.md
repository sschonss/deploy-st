# Canary Deploy com Argo Rollouts

**Data:** 2026-04-18  
**Contexto:** Extensão do deploy flow existente. Adiciona canary progressivo em production.

## Resumo

Substituir o `Deployment` do Kubernetes por um `Rollout` (CRD do Argo Rollouts) no ambiente de production. A nova versão recebe tráfego gradualmente: 20% → 40% → 60% → 80% → 100%, com 30s entre cada step. O tráfego é controlado via Nginx Ingress annotations pelo Argo Rollouts controller.

## Estratégia

- **Staging:** Continua como Deployment normal
- **Production:** Usa Rollout com canary progressivo automático

## Steps do Canary

1. Nova versão deployada → recebe 20% do tráfego
2. Espera 30s
3. Promove pra 40%
4. Espera 30s
5. Promove pra 60%
6. Espera 30s
7. Promove pra 80%
8. Espera 30s
9. Promove pra 100% — canary vira stable

## Arquivos

| Arquivo | Ação |
|---------|------|
| `helm/deploy-st/templates/deployment.yaml` | Adiciona condição `if not canary.enabled` |
| `helm/deploy-st/templates/rollout.yaml` | Novo: Rollout CRD |
| `helm/deploy-st/templates/service-canary.yaml` | Novo: Service para canary pods |
| `helm/deploy-st/values.yaml` | Adiciona `canary.enabled: false` |
| `helm/deploy-st/values-production.yaml` | `canary.enabled: true` com steps |
| `scripts/install-argocd.sh` | Instala Argo Rollouts controller |

## Dependências

- Argo Rollouts controller instalado no cluster
- Nginx Ingress controller (já instalado)
- ArgoCD (já instalado)
