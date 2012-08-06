/*
 * low_level_op.h
 *
 *  Created on: Apr 2, 2012
 *      Author: lucas.russo
 */

#ifndef LOW_LEVEL_OP_H_
#define LOW_LEVEL_OP_H_

#include <xio.h>
#include <xil_types.h>
#include <xaxidma.h>
#include "xparameters.h"

/* The DMA engine can transfer up to 8388608 bytes (=8 MB = 2^23 bits in S2MM_LENGTH register) =
 *  2097152 32-bit samples = 2^21 which is far less than the maximum size possible on the 512 MB DDR3 available
 *  on ML605 kit*/
#define MAX_DMA_TRANSFER_SIZE 8388608										/* # of bytes */

#define ADC_SAMPLE_SIZE 4													/* # of bytes. it includes channel A and B*/
#define DDC_SAMPLE_SIZE 16													/* # of bytes. it includes delta_x, delta_y and delta_z*/
#define ADC_DDC_SAMPLE_SIZE (ADC_SAMPLE_SIZE+DDC_SAMPLE_SIZE)

#define MAX_ADC_SAMPLES_COUNT (MAX_DMA_TRANSFER_SIZE/ADC_SAMPLE_SIZE -1)	/* # of samples in SAMPLE_SIZE units */
#define MAX_DDC_SAMPLES_COUNT (MAX_DMA_TRANSFER_SIZE/DDC_SAMPLE_SIZE -1)	/* # of samples in SAMPLE_SIZE units */
#define MAX_ADC_DDC_SAMPLES_COUNT ((MAX_DMA_TRANSFER_SIZE/(ADC_SAMPLE_SIZE+DDC_SAMPLE_SIZE)) -1)	/* # of samples in SAMPLE_SIZE units */

#define OFFSET_FMC150_FLAGS_PULSE_0 0x0
#define OFFSET_FMC150_FLAGS_IN_0 0x1
#define OFFSET_FMC150_FLAGS_OUT_0 0x2
#define OFFSET_FMC150_ADDR 0x3
#define OFFSET_FMC150_DATAIN 0x4
#define OFFSET_FMC150_DATAOUT 0x5
#define OFFSET_FMC150_CHIPSELECT 0x6
#define OFFSET_FMC150_ADC_DELAY 0x7

#define MASK_AND_FLAGSIN0_SPI_WRITE 0xFFFFFFFE
#define MASK_OR_FLAGSIN0_SPI_READ 0x1
#define MASK_AND_FLAGS_OUT_0_FPGA_ADC_CLK_LOCKED 0x4

#define MASK_AND_FLAGSOUT0_SPI_BUSY 0x1
#define FLAGS_IN_0_EXTERNAL_CLOCK 0x1

#define MASK_XOR_CHIPSELECT_CDCE72010 0x1
#define MASK_XOR_CHIPSELECT_ADS62P49 0x2
#define MASK_XOR_CHIPSELECT_DAC3283 0x4
#define MASK_XOR_CHIPSELECT_AMC7823 0x8

#define MASK_PULSES_ADC_DELAY_UPDATE 0x1

/* For functions read/write fmc150 register */
#define CHIPSELECT_CDCE72010 0x1
#define CHIPSELECT_ADS62P49 0x2
#define CHIPSELECT_DAC3283 0x4
#define CHIPSELECT_AMC7823 0x8

/* Number of register per chip */
#define CDCE72010_NUMREG 13
#define CDCE72010_PLL_LOCK 0x0400
#define CDCE72010_OUTPUT_DIV_MASK 0x0FE0000
#define CDCE72010_OUTPUT_DIV_SHIFT 0x011

/* DMA ids for low level handler */
#define ADC_ID 1
#define DDC_ID 2

#define MAX_PLL_LOCK_TRIES 5
#define MAX_MMCM_LOCK_TRIES 5
#define MAX_DMA_TRIES 5

/* Comamnd attr structures */
extern const struct command_attr fmc150_comm_attr;
extern const struct command_attr ddc_comm_attr;
extern const struct command_attr fmc150_ddc_comm_attr;
extern const struct command_attr soft_reg_attr;
extern const struct command_attr led_comm_attr;
extern const struct command_ops fmc150_comm_ops;
extern const struct command_ops ddc_comm_ops;
extern const struct command_ops led_comm_ops;
extern const struct command_ops soft_reg_ops;

struct low_level_attr{
	XAxiDma	AxiDma; 				/* Instance of the XAxiDma */
	XAxiDma_Config *AxiDmaConfig; 	/* DMA config */
	const u32 sample_size;
	const char *mem_start_addr;
	const u32 mem_size;
	/* include knowledge of other modules */
	const u32 max_resp_buffer_packets;
};

struct low_level_handler{
	unsigned int id;
	char *baseaddr;
	struct low_level_attr *attr;
	u32 samples_count;
	u32 samples_count_pos;
};

int get_low_level_handler(unsigned int comm, struct low_level_handler **low_level_handler);
void delay(int counts);

int update_fmc150_adc_delay(u8 adc_strobe_delay, u8 adc_cha_delay, u8 adc_chb_delay);
int capture_samples(u32 qw_count, struct low_level_handler *low_lev_handler);
int get_samples(u32 *size, u32 *byte_offset, struct low_level_handler *low_lev_handler);
int read_fmc150_register(u32 chipselect, u32 addr, volatile u32* value);
int write_fmc150_register(u32 chipselect, u32 addr, u32 val);

int read_soft_register(u32 baseaddr, u32 offset, volatile u32 *value);
int write_soft_register(u32 baseaddr, u32 offset, u32 value);

int init_cdce72010();
int init_ads62p49();
int init_fmc150_delay();

int led_read(u32 chipselect, u32 addr, volatile u32* value);
int led_write(u32 chipselect, u32 addr, u32 value);

int enable_ext_clk();
int check_mmcm_lock();
int check_ext_lock();

int dump_cdce72010_regs();
int dump_mem_adc(void *mem_start_addr, int mem_size);
int calibrate_adc_delay();

/* Dummy functions for placeholder only */
int capture_samples_dummy(u32 qw_count, struct low_level_handler *low_lev_handler);
int get_samples_dummy(u32 *size, u32 *byte_offset, struct low_level_handler *low_lev_handler);
int read_reg_dummy(u32 chipselect, u32 addr, volatile u32* value);
int write_reg_dummy(u32 chipselect, u32 addr, u32 value);

#endif /* LOW_LEVEL_OP_H_ */
