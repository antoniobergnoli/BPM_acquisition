/*
 * init.h
 *
 *  Created on: Aug 1, 2012
 *      Author: lucas.russo
 */

#ifndef _INIT_H_
#define _INIT_H_

int enable_ext_clk();

int init_cdce72010();
int init_ads62p49();

int init_fmc150_delay();

int check_ext_lock();

int check_mmcm_lock();
int dump_cdce72010_regs();

int calibrate_adc_delay();
int dump_mem_adc(void *mem_start_addr, int mem_size);

#endif /* _INIT_H_ */
