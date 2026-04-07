#!/bin/bash
# =============================================================================
# install.sh — Cluster MPI com kind + kubectl
# Aula de Computação Paralela — Exercício Token Ring MPI
#
# O que este script faz:
#   1. Verifica/instala dependências (docker, kind, kubectl)
#   2. Cria o cluster kind com múltiplos nós worker
#   3. Faz o build da imagem Docker com o programa MPI
#   4. Carrega a imagem nos nós kind (sem precisar de registry externo)
#   5. Aplica os manifests Kubernetes (workers + master job)
#   6. Aguarda e exibe os logs do master (saída da contagem)
#   7. Oferece opção de limpeza
# =============================================================================

set -euo pipefail

# ---- Cores para output -------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo -e "${RED}[ERRO]${NC}  $*" >&2; exit 1; }
step() { echo -e "\n${CYAN}===> $*${NC}"; }

CLUSTER_NAME="mpi-cluster"
IMAGE_NAME="mpi-counter:latest"
NAMESPACE="default"

# ==============================================================================
# Funções de verificação/instalação de dependências
# ==============================================================================

check_docker() {
    if ! command -v docker &>/dev/null; then
        err "Docker não encontrado. Instale em: https://docs.docker.com/engine/install/ubuntu/"
    fi
    if ! docker info &>/dev/null; then
        err "Docker daemon não está rodando. Execute: sudo systemctl start docker"
    fi
    log "Docker: OK"
}

install_kind() {
    if command -v kind &>/dev/null; then
        log "kind: OK ($(kind version))"
        return
    fi
    step "Instalando kind..."
    ARCH=$(uname -m)
    KIND_ARCH="amd64"
    [ "$ARCH" = "aarch64" ] && KIND_ARCH="arm64"
    curl -Lo /tmp/kind \
        "https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-${KIND_ARCH}"
    chmod +x /tmp/kind
    sudo mv /tmp/kind /usr/local/bin/kind
    log "kind instalado com sucesso."
}

install_kubectl() {
    if command -v kubectl &>/dev/null; then
        log "kubectl: OK ($(kubectl version --client --short 2>/dev/null || true))"
        return
    fi
    step "Instalando kubectl..."
    ARCH=$(uname -m)
    K8S_ARCH="amd64"
    [ "$ARCH" = "aarch64" ] && K8S_ARCH="arm64"
    KUBECTL_VER=$(curl -s https://dl.k8s.io/release/stable.txt)
    curl -Lo /tmp/kubectl \
        "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/${K8S_ARCH}/kubectl"
    chmod +x /tmp/kubectl
    sudo mv /tmp/kubectl /usr/local/bin/kubectl
    log "kubectl instalado com sucesso."
}

# ==============================================================================
# Setup do cluster
# ==============================================================================

create_cluster() {
    step "Criando cluster kind '${CLUSTER_NAME}'..."
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        warn "Cluster '${CLUSTER_NAME}' já existe. Pulando criação."
    else
        kind create cluster \
            --name "${CLUSTER_NAME}" \
            --config k8s/kind-cluster.yaml
        log "Cluster criado com sucesso."
    fi
    kubectl cluster-info --context "kind-${CLUSTER_NAME}"
}

build_image() {
    step "Fazendo build da imagem Docker '${IMAGE_NAME}'..."
    docker build -t "${IMAGE_NAME}" .
    log "Build concluído."
}

load_image() {
    step "Carregando imagem nos nós kind..."
    kind load docker-image "${IMAGE_NAME}" --name "${CLUSTER_NAME}"
    log "Imagem carregada em todos os nós."
}

deploy_workers() {
    step "Deployando workers MPI..."
    # Remove job anterior se existir
    kubectl delete job mpi-master --ignore-not-found=true -n "${NAMESPACE}"
    kubectl apply -f k8s/mpi-worker.yaml -n "${NAMESPACE}"

    log "Aguardando workers ficarem prontos..."
    kubectl rollout status statefulset/mpi-worker \
        --timeout=120s -n "${NAMESPACE}"
    log "Workers prontos."
}

run_master() {
    step "Executando job master MPI (contagem token ring)..."
    kubectl apply -f k8s/mpi-master.yaml -n "${NAMESPACE}"

    log "Aguardando job master completar..."
    kubectl wait --for=condition=complete job/mpi-master \
        --timeout=120s -n "${NAMESPACE}" || true

    step "=== Saída da contagem sequencial MPI ==="
    MASTER_POD=$(kubectl get pods -n "${NAMESPACE}" \
        --selector=job-name=mpi-master \
        --output=jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [ -n "$MASTER_POD" ]; then
        kubectl logs "${MASTER_POD}" -n "${NAMESPACE}"
    else
        warn "Não foi possível recuperar o pod master. Verifique: kubectl get pods"
    fi
}

show_nodes() {
    step "Nós do cluster (cada um simula um host físico MPI):"
    kubectl get nodes -o wide
}

cleanup() {
    step "Limpando recursos..."
    kubectl delete job mpi-master --ignore-not-found=true
    kubectl delete -f k8s/mpi-worker.yaml --ignore-not-found=true
    warn "Para destruir o cluster inteiro: kind delete cluster --name ${CLUSTER_NAME}"
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║   Cluster MPI — Token Ring Counter          ║"
    echo "║   Computação Paralela — kind + kubectl       ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Parse argumentos
    ACTION="${1:-run}"

    case "$ACTION" in
        run)
            check_docker
            install_kind
            install_kubectl
            create_cluster
            build_image
            load_image
            deploy_workers
            show_nodes
            run_master
            ;;
        clean)
            cleanup
            ;;
        logs)
            MASTER_POD=$(kubectl get pods \
                --selector=job-name=mpi-master \
                --output=jsonpath='{.items[0].metadata.name}' 2>/dev/null)
            kubectl logs "${MASTER_POD}"
            ;;
        rebuild)
            build_image
            load_image
            kubectl delete job mpi-master --ignore-not-found=true
            run_master
            ;;
        *)
            echo "Uso: $0 [run|clean|logs|rebuild]"
            echo "  run     — setup completo e executa (padrão)"
            echo "  clean   — remove deployments"
            echo "  logs    — exibe logs do último job"
            echo "  rebuild — rebuida imagem e re-executa o master"
            exit 1
            ;;
    esac
}

main "$@"
