/*
 * server.h
 *
 *  Created on: Apr 2, 2012
 *      Author: lucas.russo
 */

#ifndef _SERVER_H_
#define _SERVER_H_

#define BACKLOG 10

/* Functions prototypes */
void print_server_app_header();
int handle_request(struct command_packet *command_packet_r, struct response_packet *response_packet_s);
int get_command_handler(unsigned int comm, struct command_handler *comm_handler);
int get_response_handler(unsigned int comm, struct response_handler *res_handler);

void process_client_request(void *p);
void server_application_thread();

#endif /* _SERVER_H_ */
