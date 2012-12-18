library ieee;
use ieee.std_logic_1164.all;

package dma_pkg is
    --------------------------------------------------------------------
    -- Components
    --------------------------------------------------------------------
	component dma_if
	generic
	(
		-- Three 32-bit data input. LSB bits are valid.
	    C_NBITS_VALID_INPUT             	: natural := 128;
		C_NBITS_DATA_INPUT					: natural := 128;
		C_OVF_COUNTER_SIZE					: natural := 10
	);
	port
	(
		-- External Ports. S2MM (streaming to memory mapped)
		dma_clk_i             		   		: in  std_logic;
		dma_valid_o             		   	: out std_logic;
		dma_data_o              		   	: out std_logic_vector(C_NBITS_DATA_INPUT-1 downto 0);
		dma_be_o                		   	: out std_logic_vector(C_NBITS_DATA_INPUT/8 - 1 downto 0);
		dma_last_o              		   	: out std_logic;
		dma_ready_i             		   	: in  std_logic;
		
		-- From ADC
		data_clk_i		               		: in std_logic;
		data_i       	          	  		: in std_logic_vector(C_NBITS_DATA_INPUT-1 downto 0);
		data_valid_i						: in std_logic;
		data_ready_o						: out std_logic;
		
		-- Capture control
		capture_ctl_i				   		: in std_logic_vector(31 downto 0);
		dma_complete_o						: out std_logic;
		dma_ovf_o							: out std_logic;
		
		-- Reset signal
		rst_i						   		: in std_logic;
		
		-- Debug Signals
		dma_debug_clk_o            		   	: out std_logic;
		dma_debug_data_o           		   	: out std_logic_vector(255 downto 0);
		dma_debug_trigger_o        		   	: out std_logic_vector(15 downto 0)
	);
	end component dma_if;
	
	-- Should be in a separate package
	component reset_synch
	port 
	(
		clk_i     							: in  std_logic;
		asyncrst_i							: in  std_logic;
		rst_o      							: out std_logic
	);
	end component reset_synch;
	
	component dma_status_reg_synch is
	generic
	(
		C_NUM_REG                      	: integer              := 10;
		C_SLV_DWIDTH                   	: integer              := 32;
		C_STATUS_REG_IDX				: natural	   		   := 1
	);
	port
	(
		bus_clk_i						: in  std_logic;
		bus_rst_n_i						: in  std_logic;
		bus_reg_read_sel_i				: in  std_logic_vector(C_NUM_REG-1 downto 0);   
		bus_reg_write_sel_i				: in  std_logic_vector(C_NUM_REG-1 downto 0);  
		bus_2_ip_data_i					: in  std_logic_vector(C_SLV_DWIDTH-1 downto 0);
		
		dma_complete_i					: in  std_logic;
		dma_ovf_i						: in  std_logic;
		
		dma_complete_synch_o			: out  std_logic;
		dma_ovf_synch_o					: out  std_logic
	);
	end component dma_status_reg_synch;
	
end dma_pkg;