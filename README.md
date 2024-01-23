Firmware support for FMC150 Mezzanine (ADC + DAC) 
 
 
 
 
 Simple Acquisition System for ADC and Position Calculation Samples

-----------------------------------------------------------------------

 Instructions

 1 - Deploy the bistream onto the Evaluation Kit through Xilinx SDK or
		by other means.

 2 - Start the FPGA application server through the SDK application.

 3 - Acquire samples by means of Matlab scripts (located inside the 
		scripts folder) or by adhering to the application packet protocol. 
		See C code application for details.
	
-----------------------------------------------------------------------

 Input FMC150 Board Parameters

 - ADC Clock Reference = 7.68 MHz
 - ADC Channel A = 291.840 MHz (RF Frequency)
 - ADC Channel B = 291.840 MHz (RF Frequency)
 
-----------------------------------------------------------------------

 PLL (CDCE72010) Parameters

 - Input Clock reference = 7.68 MHz
 - VCXO frequency = 491.52 MHz
 - M Divider = 4
 - N Divider = 32
 - P (FB Divider) = 8
 - PFD Input Frequency = 1.92 MHz
 - Output Divider (To ADC Chip) = 5
 - Output Frequency (To ADC Chip) = 98.304 MHz
 
-----------------------------------------------------------------------

 Libera RF & Clock Generator Parameters

 - RF = 291.840 MHz
 - MCf = 7.680 MHz
 - H = 38
 - Filling Pattern = 100%
 
-----------------------------------------------------------------------

 FPGA Cores Parameters
 
 DDS Frequency = 3.072 MHz 
 DDS Phase increment = 2048d
 
-----------------------------------------------------------------------

	
