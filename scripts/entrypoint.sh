#!/bin/bash
# entrypoint.sh
# O pod master recebe ROLE=master e executa mpirun.
# Os pods workers apenas sobem o SSH e ficam aguardando.

set -e

# Inicia o serviço SSH em todos os nós (master e workers precisam)
service ssh start

ROLE=${ROLE:-worker}
N=${N:-20}
NP=${NP:-4}

if [ "$ROLE" = "master" ]; then
    echo "=== Nó MASTER iniciando ==="
    echo "Aguardando workers ficarem prontos (5s)..."
    sleep 5

    # Gera o hostfile a partir das variáveis de ambiente WORKER_HOSTS
    # Ex: WORKER_HOSTS="mpi-worker-0,mpi-worker-1,mpi-worker-2"
    HOSTFILE=/tmp/hosts.txt
    echo "localhost slots=1" > "$HOSTFILE"

    if [ -n "$WORKER_HOSTS" ]; then
        IFS=',' read -ra WORKERS <<< "$WORKER_HOSTS"
        for w in "${WORKERS[@]}"; do
            echo "$w slots=1" >> "$HOSTFILE"
        done
    fi

    echo "=== Hostfile ==="
    cat "$HOSTFILE"
    echo "================"

    echo "Executando: mpirun -np $NP --hostfile $HOSTFILE ./counter $N"
    mpirun -np "$NP" \
           --hostfile "$HOSTFILE" \
           --allow-run-as-root \
           ./counter "$N"

    echo "=== Execução concluída ==="
else
    echo "=== Nó WORKER pronto ($(hostname)) — aguardando comandos do master ==="
    # Mantém o container vivo aguardando conexões SSH do mpirun
    tail -f /dev/null
fi
