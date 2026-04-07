FROM ubuntu:22.04

# Instala OpenMPI, SSH (necessário para comunicação entre pods/hosts) e ferramentas básicas
RUN apt-get update && apt-get install -y \
    openmpi-bin \
    libopenmpi-dev \
    openssh-server \
    openssh-client \
    gcc \
    make \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Configura SSH sem senha para comunicação MPI entre nós
RUN mkdir -p /root/.ssh && \
    ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys && \
    echo "StrictHostKeyChecking no" >> /root/.ssh/config && \
    echo "UserKnownHostsFile=/dev/null" >> /root/.ssh/config

# Configura SSHD
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Diretório de trabalho
WORKDIR /mpi

# Copia o código-fonte
COPY src/counter.c .

# Compila
RUN mpicc -o counter counter.c

# Script de entrypoint: inicia SSH e aguarda (workers) ou executa mpirun (master)
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
