#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mpi.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>

//void get_ip(char *ip_buf) {
//    char hostname[MPI_MAX_PROCESSOR_NAME];
//    struct addrinfo hints, *res;
//    gethostname(hostname, sizeof(hostname));
//    memset(&hints, 0, sizeof(hints));
//    hints.ai_family = AF_INET;
//    if (getaddrinfo(hostname, NULL, &hints, &res) == 0) {
//        struct sockaddr_in *addr = (struct sockaddr_in *)res->ai_addr;
//        inet_ntop(AF_INET, &addr->sin_addr, ip_buf, INET_ADDRSTRLEN);
//        freeaddrinfo(res);
//    } else {
//        strcpy(ip_buf, "desconhecido");
//    }
//}

void get_ip(char *ip_buf) {
    struct ifaddrs *ifaddr, *ifa;

    if (getifaddrs(&ifaddr) == -1) {
        strcpy(ip_buf, "erro");
        return;
    }

    for (ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
        if (!ifa->ifa_addr) continue;

        // Apenas IPv4
        if (ifa->ifa_addr->sa_family != AF_INET)
            continue;

        // Interface precisa estar ativa
        if (!(ifa->ifa_flags & IFF_UP))
            continue;

        // Ignora loopback
        if (ifa->ifa_flags & IFF_LOOPBACK)
            continue;

        struct sockaddr_in *addr = (struct sockaddr_in *)ifa->ifa_addr;

        char ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &addr->sin_addr, ip, sizeof(ip));

        // Ignora 127.*
        if (strncmp(ip, "127.", 4) == 0)
            continue;

        strcpy(ip_buf, ip);
        freeifaddrs(ifaddr);
        return;
    }

    strcpy(ip_buf, "desconhecido");
    freeifaddrs(ifaddr);
}

int main(int argc, char *argv[]) {
    int rank, size, token;
    
    int N = 20;
    if (argc>1) N = atoi(argv[1]);

    char hostname[MPI_MAX_PROCESSOR_NAME];
    char ip[INET_ADDRSTRLEN];
    int namelen;

    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    MPI_Get_processor_name(hostname, &namelen);
    get_ip(ip);

    if (rank == 0) {
        token = 0;
        while (token <= N) {
            printf("Rank %d | %s | %s | imprime: %d\n", rank, ip, hostname, token);
            fflush(stdout);
            token++;
            if (token <= N)
                MPI_Send(&token, 1, MPI_INT, 1, 0, MPI_COMM_WORLD);
            else {
                int fim = N + 1;
                MPI_Send(&fim, 1, MPI_INT, 1, 0, MPI_COMM_WORLD);
            }
            if (token <= N)
                MPI_Recv(&token, 1, MPI_INT, size - 1, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            else
                break;
        }
    } else {
        while (1) {
            MPI_Recv(&token, 1, MPI_INT, rank - 1, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            if (token > N) {
                if (rank != size - 1)
                    MPI_Send(&token, 1, MPI_INT, rank + 1, 0, MPI_COMM_WORLD);
                break;
            }
            printf("Rank %d | %s | %s | imprime: %d\n", rank, ip, hostname, token);
            fflush(stdout);
            token++;
            int next = (rank + 1) % size;
            MPI_Send(&token, 1, MPI_INT, next, 0, MPI_COMM_WORLD);
        }
    }

    MPI_Finalize();
    return 0;
}
