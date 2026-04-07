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

    if (rank == 0)
    {
        token = 0;
        printf("[proc %d | %s | %s] -> %d\n", rank, hostname, ip, token);
        fflush(stdout);
        token = 1;
        MPI_Send(&token, 1, MPI_INT, 1 % size, 0, MPI_COMM_WORLD);

        while (1) 
        {
            MPI_Recv(&token, 1, MPI_INT, size - 1, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            if (token>N) break;
            printf("[proc %d | %s | %s] -> %d\n", rank, hostname, ip, token);
            fflush(stdout);
            token++;
            int next = (size==1) ? 0 : 1;
            MPI_Send(&token, 1, MPI_INT, next, 0, MPI_COMM_WORLD);
            if (token > N) break;
        }

    } 
    else 
    {
        // Lógica do anel de processos 
        int prev = rank - 1;
        int next = (rank + 1) % size;

        // Loop while para passar para o próximo processo (0 a N-1)
        while (1) 
        {
            // Recebe do buffer
            MPI_Recv(&token, 1, MPI_INT, prev, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            
            if (token>N) 
            {
                MPI_Send(&token, 1, MPI_INT, next, 0, MPI_COMM_WORLD);
                break;
            }
            printf("[proc %d | %s | %s] -> %d\n", rank, hostname, ip, token);
            fflush(stdout);
            token++;
            MPI_Send(&token, 1, MPI_INT, next, 0, MPI_COMM_WORLD);
        }
    }

    MPI_Finalize();
    return 0;
}
