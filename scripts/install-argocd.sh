#!/usr/bin/env bash
set -euo pipefail

echo "=== Deploy ST — ArgoCD Installation ==="
echo ""

echo "📦 Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ""
echo "⏳ Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

echo ""
echo "🔑 ArgoCD admin password:"
ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "   Username: admin"
echo "   Password: $ARGO_PWD"

echo ""
echo "📋 Applying ArgoCD Applications..."
kubectl apply -f argocd/staging-app.yaml
kubectl apply -f argocd/production-app.yaml

echo ""
echo "=== ArgoCD Installation Complete ==="
echo ""
echo "To access the ArgoCD dashboard, run:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Then open: https://localhost:8080"
echo "  Username: admin"
echo "  Password: $ARGO_PWD"
