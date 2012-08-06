/*
 * connection_server.h
 *
 *  Created on: Apr 2, 2012
 *      Author: lucas.russo
 */

#ifndef _CONNECTION_SERVER_H_
#define _CONNECTION_SERVER_H_

#include "common.h"

#define CLIENT_PORT "8006"  // the port users will be connecting to*/

#define BACKLOG 10    // how many pending connections queue will hold

/* Client/Server connection functions */

/* Send/Receive funtions */
int recv_command_packet(int sockfd, struct command_packet
		*command_packet, int flags);
int send_response_packet(int sockfd, struct response_packet
		*response_packet, int flags);
void generate_data(struct command_packet *command_packet,
		struct response_packet *response_packet);
int sendall(int sockfd, unsigned char *send_buf, int len, int flags);
int recvall(int sockfd, unsigned char *recv_buf, int len, int flags);


#endif //_CONNECTION_CLIENT_H_
