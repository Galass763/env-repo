#!/bin/bash

echo "🔄 Réinstallation d'ArgoCD..."

# Supprimer si existe
kubectl delete namespace argocd --ignore-not-found=true
sleep 10

# Créer et installer
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Attente que ArgoCD soit prêt..."
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

# Password
sleep 10
PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
echo "✅ ArgoCD installé!"
echo "Password: $PASS"
echo "$PASS" > ~/argocd-password.txt

# Namespaces
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -

# Labels
kubectl label namespace dev environment=dev --overwrite
kubectl label namespace staging environment=staging --overwrite
kubectl label namespace production environment=production --overwrite

echo "✅ Namespaces créés et labellisés"
echo ""
echo "Pour accéder:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  https://localhost:8080"
echo "  Username: admin"
echo "  Password: voir ~/argocd-password.txt"
