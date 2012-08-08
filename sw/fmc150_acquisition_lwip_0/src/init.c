/*
 * init.c
 *
 *  Created on: Aug 1, 2012
 *      Author: lucas.russo
 */

#include <stdio.h>

#include "common.h"
#include "init.h"

/* Register values for cdce72010 */
u32 cdce72010_reg[CDCE72010_NUMREG] = {
//internal reference clock. Default config.
	/*0x683C0310,
	0x68000021,
	0x83040002,
	0x68000003,
	0xE9800004,
	0x68000005,
	0x68000006,
	0x83800017,
	0x68000098,
	0x68050CC9,
	0x05FC270A,
	0x0280044B,
	0x0000180C*/

//3.84MHz ext clock. Does not lock.
	/*0x682C0290,
	0x68840041,
	0x83840002,
	0x68400003,
	0xE9800004,
	0x68000005,
	0x68000006,
	0x83800017,
	0x68000098,
	0x68000C49,
	0x0BFC02FA,
	0x8000050B,
	0x0000180C*/

//61.44MHz ext clock. LOCK.
	/*0x682C0290,
	0x68840041,
	0x83040002,
	0x68400003,
	0xE9800004,
	0x68000005,
	0x68000006,
	0x83800017,
	0x68000098,
	0x68000049,
	0x0024009A,
	0x8000050B,
	0x0000180C*/

//7.68MHz ext clock. Lock.
// Use with Libera RF & clock generator. RF = 291.840MHz, MCf = 7.680MHz, H = 38
// DDS = 3.072MHz -> Phase increment = 2048d
	0x682C0290,
	0x68840041,
	0x83860002, 	//divide by 5
	//0x83840002,		//divide by 4
	0x68400003,
	0xE9800004,
	0x68000005,
	0x68000006,
	0x83800017,
	0x68000098,
	0x68000049,
	0x007C003A, // PFD_freq = 1.92MHz
	0x8000050B,
	0x0000180C

//15.36MHz ext clock.
	/*0x682C0290,
	0x68840041,
	0x83840002,
	/*;83020002,;divide by 6
	;83860002,	;divide by 5
	;83800002,	;divide by 2
	;83840002,	;divide by 4
	;83060002,	;divide by 8
	0x68400003,
	0xE9800004,
	0x68000005,
	0x68000006,
	0x83800017,
	0x68000098,
	0x68000049,
	0x003C003A,
	0x8000050B,
	0x0000180C*/

//9.6MHz ext clock.
	/*0x682C0290,
	0x68840041,
	0x83860002,//;divide by 5
	0x68400003,
	0xE9800004,
	0x68000005,
	0x68000006,
	0x83800017,
	0x68000098,
	0x68000049,
	0x007C004A,
	0x8000050B,
	0x0000180C*/

	//9.250MHz ext clock. No lock
	/*0x682C0290,
	0x68840041,
	0x83860002,
	0x68400003,
	0xE9800004,
	0x68000005,
	0x68000006,
	0x83800017,
	0x68000098,
	0x68000049,
	0x5FFC39CA,
	//0x8000390B,	// DIvide by 32
	0x8000050B, //Divide by 8
	0x0000180C*/

	//10.803 (originally 10.803 actually) ext clock.
	//Could it be something related to the lock window? see cdce72010 datasheet
	/*0x682C0290,
	0x68840041,
	0x83840002,
	0x68400003,
	0xE9800004,
	0x68000005,
	0x68000006,
	0x83800017,
	0x68000098,
	0x68000049,
	0x03FC02CA,
	0x8000050B,
	0x0000180C*/
};

int enable_ext_clk(){
	u32 aux_value;

	// set External Clock for FMC150
	aux_value = XIo_In32(FMC150_BASEADDR+OFFSET_FMC150_FLAGS_IN_0*0x4);
#ifdef INIT_DEBUG
	xil_printf("flags in value = %08X\n", aux_value);
#endif
	XIo_Out32(FMC150_BASEADDR+OFFSET_FMC150_FLAGS_IN_0*0x4, aux_value | 0x02);
#ifdef INIT_DEBUG
	xil_printf("flags in value = %08X\n", XIo_In32(FMC150_BASEADDR + OFFSET_FMC150_FLAGS_IN_0*0x4));
	xil_printf("flags out value = %08X\n", XIo_In32(FMC150_BASEADDR + OFFSET_FMC150_FLAGS_OUT_0*0x4));
#endif

	// 200ms delay. It is needed 50ms for EEPROM to configure cdce72010
	delay(200);

	return SUCCESS;
}

int init_cdce72010()
{
	int i;
	volatile u32 value;

	/* Write regs to cdce72010 statically */
	for(i = 0; i < CDCE72010_NUMREG; ++i){
		while(read_fmc150_register(CHIPSELECT_CDCE72010, i, &value) < 0){
			xil_printf("cdce72010 SPI busy\n");
			delay(1000);
		}
#ifdef INIT_DEBUG
		xil_printf("init_cdce72010: cdce72010 reg %2X before write: %08X\n", i, value);
		xil_printf("init_cdce72010: cdce72010 mem pos %d: %08X\n", i, cdce72010_reg[i]);
#endif

		write_fmc150_register(CHIPSELECT_CDCE72010, i, cdce72010_reg[i]);
		delay(10);
		/* Do a write-read cycle in order to ensure that we wrote the correct value */
	    while(read_fmc150_register(CHIPSELECT_CDCE72010, i, &value) < 0){
	    	xil_printf("cdce72010 SPI busy\n");
	    	delay(100);
	    }
#ifdef INIT_DEBUG
	    xil_printf("init_cdce72010: cdce72010 reg %2X after write: %08X\n", i, value);
#endif
	}

	return SUCCESS;
}

int init_ads62p49()
{
	volatile u32 value;

	/* Read register # 2 from cdce 72010 */
	while(read_fmc150_register(CHIPSELECT_CDCE72010, 0x2, &value) < 0){
		xil_printf("init_ads62p49: cdce72010 SPI busy\n");
		delay(100);
	}

	/* extract only the output divider part */
	value = ((value & CDCE72010_OUTPUT_DIV_MASK) >> CDCE72010_OUTPUT_DIV_SHIFT);

	switch(value){

		case 0x20:	//divide by 1. ADC_freq = 491.52MHz
		case 0x40:	//divide by 2. ADC_freq = 245.76MHz
		case 0x41:	//divide by 3. ADC_freq = 163.84MHz
		case 0x42:	//divide by 4. ADC_freq = 122.88MHz
		case 0x43:	//divide by 5. ADC_freq = 98.304MHz
		case 0x00:	//divide by 4'. ADC_freq = 122.88MHz
		case 0x01:  //divide by 6. ADC_freq = 81.92MHz
			/* Disable low speed mode. > 80MSPS */
			write_fmc150_register(CHIPSELECT_ADS62P49, 0x020, 0x00);
			break;

		/* Divide by greater than 6. ADC_freq <= 61.44 */
		default:
			/* Enable low speed mode. < 80MSPS */
			write_fmc150_register(CHIPSELECT_ADS62P49, 0x020, 0x04);
	}

    while(read_fmc150_register(CHIPSELECT_ADS62P49, 0x020, &value) < 0){
    	xil_printf("init_ads62p49: ads62p49 SPI busy\n");
    	delay(100);
    }

	xil_printf("init_ads62p49: ads62p49 reg 0x020  = %08X\n", value);

	return SUCCESS;
}

int init_fmc150_delay()
{
	u8 adc_strobe_delay = 0, adc_cha_delay, adc_chb_delay;
	volatile u32 value;

	/* Read register # 2 from cdce 72010 */
	while(read_fmc150_register(CHIPSELECT_CDCE72010, 0x2, &value) < 0){
		xil_printf("init_fmc150_delay: cdce72010 SPI busy\n");
		delay(100);
	}

	/* extract only the output divider part */
	value = ((value & CDCE72010_OUTPUT_DIV_MASK) >> CDCE72010_OUTPUT_DIV_SHIFT);

	switch(value){

		case 0x20:	//divide by 1. ADC_freq = 491.52MHz
		case 0x40:	//divide by 2. ADC_freq = 245.76MHz
		case 0x41:	//divide by 3. ADC_freq = 163.84MHz
		//Possibly different values for delay
		case 0x42:	//divide by 4. ADC_freq = 122.88MHz
		case 0x00:	//divide by 4'. ADC_freq = 122.88MHz
			adc_cha_delay = adc_chb_delay = 0x11;
			break;
		case 0x43:	//divide by 5. ADC_freq = 98.304MHz
			adc_cha_delay = adc_chb_delay = 0x8;
			//adc_cha_delay = 0x16;
			//adc_chb_delay = 0x0B;
			break;
		case 0x01:  //divide by 6. ADC_freq = 81.92MHz
			adc_cha_delay = adc_chb_delay = 0x06;
			break;

		/* Divide by greater than 6. ADC_freq <= 61.44 */
		default:
			adc_cha_delay = adc_chb_delay = 0x05;
	}

	if(update_fmc150_adc_delay(adc_strobe_delay, adc_cha_delay, adc_chb_delay) < 0){
		xil_printf("init_fmc150_delay: Error updating adc_delay!\n");
		return ERROR;
	}

	xil_printf("init_fmc150_delay: Channel A delay updated to 0x%02X\ninit_fmc150_delay: Channel B delay updated to 0x%02X\n",
			adc_cha_delay, adc_chb_delay);

	return SUCCESS;
}

int check_ext_lock()
{
	int i;
	volatile u32 value = 0;

	for(i = 0; i < MAX_PLL_LOCK_TRIES; i++){
		delay(10);
		while(read_fmc150_register(CHIPSELECT_CDCE72010, 0xC, &value) < 0){
#ifdef INIT_DEBUG
			xil_printf("check_ext_lock: cdce72010 SPI busy\n");
#endif
			delay(100);
		}
#ifdef INIT_DEBUG
		xil_printf("check_ext_lock: cdce72010 reg 0xC: %08X\n", value);
#endif

		if((value & CDCE72010_PLL_LOCK)){
			return SUCCESS;
		}

#ifdef INIT_DEBUG
		xil_printf("check_ext_lock: cdce72010 PLL NOT locked\n");
#endif
		delay(1000);
	}

	return ERROR;
}

int check_mmcm_lock()
{
	int i;

	for(i = 0; i < MAX_MMCM_LOCK_TRIES; i++){
#ifdef INIT_DEBUG
		xil_printf("check_mmcm_lock: fmc150_flags_out: %08X\n", XIo_In32(FMC150_BASEADDR + OFFSET_FMC150_FLAGS_OUT_0*0x4));
#endif
		if((XIo_In32(FMC150_BASEADDR + OFFSET_FMC150_FLAGS_OUT_0*0x4) &
				MASK_AND_FLAGS_OUT_0_FPGA_ADC_CLK_LOCKED)){
			return SUCCESS;
		}
#ifdef INIT_DEBUG
		xil_printf("check_mmcm_lock: MMCM NOT locked\n");
#endif
		delay(100);
	}

	return ERROR;
}

int dump_cdce72010_regs()
{
	int i;
	volatile u32 value;

	xil_printf("--------------------------\n");
	xil_printf("cdce72010 regs:\n");
	delay(100);
	for(i = 0; i < CDCE72010_NUMREG; ++i){
		while(read_fmc150_register(CHIPSELECT_CDCE72010, i, &value) < 0){
			xil_printf("cdce72010 SPI busy\n");
			// 100ms delay
			delay(100);
		}

		xil_printf("cdce72010 reg 0x%02X: 0x%08X\n", i, value);
	}
	xil_printf("--------------------------\n");

	return SUCCESS;
}

int calibrate_adc_delay()
{
	int i;

	for(i = 0; i < 32; ++i){
		xil_printf("updating delay to %02X\n", i);
		if(update_fmc150_adc_delay(0x00, i, i) < 0){
			xil_printf("Error updating adc_delay!\n");
			return -1;
		}

		delay(2000);
	}

	return SUCCESS;
}

int dump_mem_adc(void *mem_start_addr, int mem_size)
{
	int i;

	xil_printf("dump_mem_adc\n");
	xil_printf("------------------------\nmem start addr = %08X, mem size = %08X\n", mem_start_addr, mem_size);

	for(i = 0; i < mem_size/ADC_SAMPLE_SIZE; ++i){
		xil_printf("%d:\t%d\t%d\n",
				i,
				*((short int *)((char *)mem_start_addr+i*ADC_SAMPLE_SIZE+2)),
				*((short int *)((char *)mem_start_addr+i*ADC_SAMPLE_SIZE)));
	}

	xil_printf("------------------------\n");


	return SUCCESS;
}
