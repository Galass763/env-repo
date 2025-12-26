#!/bin/bash

echo "=== DÉMONSTRATION AUTO-REMÉDIATION GITOPS ==="
echo ""

# --- 1️⃣ Déploiement non-conforme (image latest) ---
echo "1. Tentative de déploiement avec image 'latest' (devrait être bloqué par OPA)"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-deployment
  namespace: production
  labels:
    app: bad-app
    environment: production
    owner: team-test
    version: latest
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad-app
  template:
    metadata:
      labels:
        app: bad-app
    spec:
      containers:
      - name: nginx
        image: nginx:latest  # ❌ Violates Gatekeeper
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
EOF
echo "Résultat attendu: Admission refusée par OPA Gatekeeper"
echo ""

# --- 2️⃣ Déploiement non-conforme (labels manquants) ---
echo "2. Tentative de déploiement sans labels obligatoires (devrait être bloqué)"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: no-labels-deployment
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test  # ❌ MANQUE: environment, owner, version
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
EOF
echo "Résultat attendu: Admission refusée - labels manquants"
echo ""

# --- 3️⃣ Déploiement conforme ---
echo "3. Déploiement conforme (devrait réussir)"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: good-deployment
  namespace: production
  labels:
    app: good-app
    environment: production
    owner: team-platform
    version: v1.0.0
spec:
  replicas: 3
  selector:
    matchLabels:
      app: good-app
  template:
    metadata:
      labels:
        app: good-app
        environment: production
        owner: team-platform
        version: v1.0.0
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: nginx
        image: nginx:1.21
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
EOF
echo "Résultat attendu: Déploiement créé avec succès"
echo ""

# --- 4️⃣ Modification manuelle (drift) ---
echo "4. Modification manuelle du déploiement géré par ArgoCD (scale replicas à 5)"
kubectl -n production scale deployment good-deployment --replicas=5

echo "ArgoCD détectera le drift et restaurera l'état depuis Git (replicas=3)"
echo "Vérification dans 30 secondes..."
sleep 30

echo ""
echo "État après auto-remédiation:"
kubectl get deployment good-deployment -n production -o jsonpath='{.spec.replicas}'
echo " replicas (devrait être 3)"
echo ""

# --- 5️⃣ Audit des violations OPA Gatekeeper ---
echo "5. Audit des violations OPA Gatekeeper"
kubectl get constraints -A
echo ""

echo "6. Détails des violations spécifiques"
kubectl describe k8sblocklatestimages block-latest-images || echo "Aucune violation pour block-latest-images"
kubectl describe k8sblockrootuser block-root-user || echo "Aucune violation pour block-root-user"
kubectl describe k8srequiredlabels require-labels || echo "Aucune violation pour require-labels"
echo ""

echo "=== FIN DE LA DÉMONSTRATION ==="
