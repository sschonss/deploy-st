#!/usr/bin/env bash
set -euo pipefail

echo "=== Deploy ST — Minikube Setup ==="
echo ""

if minikube status | grep -q "Running"; then
    echo "✅ Minikube is already running"
else
    echo "🚀 Starting Minikube..."
    minikube start --driver=docker --cpus=2 --memory=4096
fi

echo ""
echo "📦 Enabling addons..."
minikube addons enable ingress
minikube addons enable metrics-server

echo ""
echo "📁 Creating namespaces..."
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Cluster:     $(kubectl cluster-info | head -1)"
echo "Namespaces:  staging, production, argocd"
echo ""
echo "Next step: ./scripts/install-argocd.sh"
