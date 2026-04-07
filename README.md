# Contagem Sequencial MPI — Token Ring em Cluster Kubernetes

**Exercício:** Contar de 0 até N com múltiplos processos MPI, cada processo imprimindo um número por vez, em ordem estrita, rodando em hosts distintos.

---

## Lógica do Algoritmo

### Token Ring

```
Proc 0  →  Proc 1  →  Proc 2  →  Proc 3
  ↑                                 |
  └─────────────────────────────────┘
```

1. **Proc 0** inicia com `token = 0`, imprime, incrementa e envia para o Proc 1.
2. Cada processo recebe o token, imprime, incrementa e passa para o próximo.
3. Quando `token > N`, o processo propaga o sinal de parada pelo anel e termina.
4. O anel garante **ordem estrita**: só um processo imprime por vez.

### Por que token ring?

- Sem semáforos, sem barreiras globais.
- Completamente descentralizado.
- Funciona com qualquer quantidade de processos (desde que `P ≤ N`).

---

## Estrutura do Projeto

```
mpi-cluster/
├── src/
│   └── counter.c          ← Programa MPI em C
├── k8s/
│   ├── kind-cluster.yaml  ← Cluster kind: 1 control-plane + 3 workers
│   ├── mpi-worker.yaml    ← StatefulSet dos processos worker
│   └── mpi-master.yaml    ← Job do processo master (executa mpirun)
├── scripts/
│   └── entrypoint.sh      ← Entrypoint dos containers
├── Dockerfile             ← Imagem Ubuntu + OpenMPI + código compilado
├── install.sh             ← Script de automação completo
└── README.md
```

---

## Pré-requisitos

- Ubuntu 22.04 (ou similar)
- Docker instalado e rodando
- Usuário com permissão no grupo `docker`
- Acesso à internet para o `install.sh` baixar `kind` e `kubectl`

---

## Como Executar

### Setup completo (recomendado)

```bash
chmod +x install.sh
./install.sh run
```

O script faz tudo:
1. Instala `kind` e `kubectl` se necessário
2. Cria o cluster kind com 3 nós worker
3. Faz build da imagem Docker
4. Carrega a imagem nos nós
5. Sobe os workers e o master
6. Exibe a saída da contagem

### Execução local (sem Kubernetes)

```bash
# Instala OpenMPI
sudo apt install openmpi-bin libopenmpi-dev -y

# Compila
mpicc -o counter src/counter.c

# Executa com 4 processos, contando até 20
mpirun -np 4 ./counter 20
```

### Saída esperada

```
[proc 0 | mpi-master-xxx]   -> 0
[proc 1 | mpi-worker-0]     -> 1
[proc 2 | mpi-worker-1]     -> 2
[proc 3 | mpi-worker-2]     -> 3
[proc 0 | mpi-master-xxx]   -> 4
[proc 1 | mpi-worker-0]     -> 5
...
[proc 3 | mpi-worker-2]     -> 20
```

O hostname diferente em cada linha **comprova** que processos estão em hosts distintos.

---

## Por que kind + kubectl para MPI?

Em um cluster MPI real, os processos precisam:
- Rodar em **hosts fisicamente distintos**
- Se comunicar via **rede** (não memória compartilhada)
- Ter **SSH** disponível entre nós (o OpenMPI usa SSH para lançar processos remotos)

O kind simula isso criando múltiplos containers Docker como se fossem VMs/hosts separados. Cada nó kind tem seu próprio hostname e namespace de rede, tornando o ambiente equivalente ao de um cluster real.

### Alternativa para cluster real (bare-metal)

1. Instale OpenMPI em cada máquina:
   ```bash
   sudo apt install openmpi-bin libopenmpi-dev -y
   ```

2. Configure SSH sem senha entre todos os nós.

3. Crie o `hosts.txt`:
   ```
   192.168.1.10 slots=1
   192.168.1.11 slots=1
   192.168.1.12 slots=1
   ```

4. Compile e execute:
   ```bash
   mpicc -o counter src/counter.c
   mpirun -np 4 --hostfile hosts.txt ./counter 20
   ```

---

## Comandos úteis

```bash
# Ver status dos pods
kubectl get pods -o wide

# Ver logs do master
./install.sh logs

# Recompilar e re-executar
./install.sh rebuild

# Limpar deployments (manter cluster)
./install.sh clean

# Destruir cluster completamente
kind delete cluster --name mpi-cluster
```

---

## Integrantes do Grupo

| Nome | RA |
|------|----|
|   Lucas Bottino   |  -  |
|    Gabriel Moura  |  -  |
|    Gabriel Castelo  |  -  |
|   Cauã Matheus   |  -  |
