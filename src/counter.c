#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <string.h>

void get_ip(char *hostname, char *ip) 
{
    struct hostent *he;
    struct in_addr **addr_list;

    if ((he = gethostbyname(hostname)) == NULL) 
    {
        strcpy(ip, "unknown");
        return;
    }

    addr_list = (struct in_addr **) he->h_addr_list;

    if (addr_list[0] != NULL) strcpy(ip, inet_ntoa(*addr_list[0]));
    else strcpy(ip, "unknown");
}

int main(int argc, char *argv[]) 
{
    int rank, size, N, token;
    
    char hostname[256];
    char ip[100];

    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    N = (argc > 1) ? atoi(argv[1]) : 10;
    gethostname(hostname, sizeof(hostname));
    get_ip(hostname, ip);

    if (rank == 0 && N < size) fprintf(stderr, "Aviso: N=%d < processos=%d; nem todos imprimirao.\n", N, size);

    // Lógica do anel de processos
    int prev = rank == 0 ? size - 1 : rank - 1;
    int next = (rank + 1) % size;

    if(rank == 0) {
        token = 0;
        printf("[proc %d | %s | %s] -> %d\n", rank, hostname, ip, token);
        MPI_Send(&token, 1, MPI_INT, next, 0, MPI_COMM_WORLD);
    }
    
    do {
        // Recebe do buffer
        MPI_Recv(&token, 1, MPI_INT, prev, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        if (token < N) {
            token++;
            printf("[proc %d | %s | %s] -> %d\n", rank, hostname, ip, token);
            fflush(stdout);
        }
        MPI_Send(&token, 1, MPI_INT, next, 0, MPI_COMM_WORLD);
    } while(token < N);

    MPI_Finalize();
    return 0;
}
