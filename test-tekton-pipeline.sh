#!/bin/bash

# Script pour tester le pipeline Tekton

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo ""
echo "=============================================="
echo "   TEST DU PIPELINE TEKTON - APP REPO        "
echo "=============================================="
echo ""

print_info "Vérification des Tasks Tekton..."
kubectl get tasks -n ci-cd

echo ""
print_info "Vérification du Pipeline..."
kubectl get pipelines -n ci-cd

echo ""
print_warning "Note: Pour exécuter le pipeline complet, vous devez:"
echo "  1. Avoir vos repositories Git (app-repo et env-repo) configurés"
echo "  2. Avoir un registry Docker accessible"
echo "  3. Avoir configuré les credentials Git et Docker"
echo ""

print_info "Création d'un PipelineRun de test (sans exécution réelle)..."

cat > /tmp/test-pipelinerun.yaml <<'EOF'
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: test-pipeline-run-
  namespace: ci-cd
spec:
  pipelineRef:
    name: build-and-deploy
  params:
    - name: APP_REPO
      value: "https://github.com/Galass763/app-repo.git"
    - name: ENV_REPO
      value: "https://github.com/Galass763/env-repo.git"
    - name: IMAGE_NAME
      value: "docker.io/Galass763/python-gitops-app"
    - name: IMAGE_TAG
      value: "v1.0.0"
  workspaces:
    - name: shared-workspace
      persistentVolumeClaim:
        claimName: workspace-pvc
EOF

print_success "Fichier PipelineRun créé: /tmp/test-pipelinerun.yaml"

echo ""
print_info "Pour exécuter le pipeline, utilisez:"
echo "  kubectl create -f /tmp/test-pipelinerun.yaml -n ci-cd"

echo ""
print_info "Test d'une Task simple..."

kubectl create -f - <<'EOF'
---
apiVersion: tekton.dev/v1beta1
kind: TaskRun
metadata:
  generateName: test-hello-
  namespace: ci-cd
spec:
  taskSpec:
    steps:
      - name: echo
        image: alpine:3.15
        script: |
          #!/bin/sh
          echo "Hello from Tekton!"
          echo "Pipeline is working correctly"
          date
EOF

sleep 3

LATEST_TASKRUN=$(kubectl get taskruns -n ci-cd --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')

if [ -n "$LATEST_TASKRUN" ]; then
    print_info "TaskRun créé: $LATEST_TASKRUN"
    print_info "Attente de la completion..."
    
    kubectl wait --for=condition=Succeeded taskrun/$LATEST_TASKRUN -n ci-cd --timeout=60s || true
    
    STATUS=$(kubectl get taskrun/$LATEST_TASKRUN -n ci-cd -o jsonpath='{.status.conditions[0].status}')
    
    if [ "$STATUS" = "True" ]; then
        print_success "TaskRun exécuté avec succès!"
        echo ""
        print_info "Logs du TaskRun:"
        kubectl logs -n ci-cd -l tekton.dev/taskRun=$LATEST_TASKRUN
    else
        print_warning "TaskRun n'est pas encore complété ou a échoué"
    fi
else
    print_warning "Impossible de trouver le TaskRun"
fi

echo ""
echo "=============================================="
echo "   ACCÈS AU TEKTON DASHBOARD                 "
echo "=============================================="
echo ""

print_info "Pour accéder au Tekton Dashboard:"
echo ""
echo "1. Port-forward:"
echo "   kubectl port-forward svc/tekton-dashboard -n ci-cd 9097:9097"
echo ""
echo "2. Ouvrir dans le navigateur:"
echo "   http://localhost:9097"
echo ""

print_info "Liste des TaskRuns récents:"
kubectl get taskruns -n ci-cd --sort-by=.metadata.creationTimestamp | tail -10

echo ""
print_info "Liste des PipelineRuns:"
kubectl get pipelineruns -n ci-cd 2>/dev/null || echo "Aucun PipelineRun trouvé"

echo ""
print_success "Test Tekton terminé!"
echo ""
