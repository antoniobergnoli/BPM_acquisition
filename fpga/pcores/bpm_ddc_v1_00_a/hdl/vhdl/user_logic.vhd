------------------------------------------------------------------------------
-- user_logic.vhd - entity/architecture pair
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 1995-2011 Xilinx, Inc.  All rights reserved.            **
-- **                                                                       **
-- ** Xilinx, Inc.                                                          **
-- ** XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS"         **
-- ** AS A COURTESY TO YOU, SOLELY FOR USE IN DEVELOPING PROGRAMS AND       **
-- ** SOLUTIONS FOR XILINX DEVICES.  BY PROVIDING THIS DESIGN, CODE,        **
-- ** OR INFORMATION AS ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE,        **
-- ** APPLICATION OR STANDARD, XILINX IS MAKING NO REPRESENTATION           **
-- ** THAT THIS IMPLEMENTATION IS FREE FROM ANY CLAIMS OF INFRINGEMENT,     **
-- ** AND YOU ARE RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE      **
-- ** FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY DISCLAIMS ANY              **
-- ** WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE               **
-- ** IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR        **
-- ** REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF       **
-- ** INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS       **
-- ** FOR A PARTICULAR PURPOSE.                                             **
-- **                                                                       **
-- ***************************************************************************
--
------------------------------------------------------------------------------
-- Filename:          user_logic.vhd
-- Version:           1.00.a
-- Description:       User logic.
-- Date:              Mon May 14 15:59:47 2012 (by Create and Import Peripheral Wizard)
-- VHDL Standard:     VHDL'93
------------------------------------------------------------------------------
-- Naming Conventions:
--   active low signals:                    "*_n"
--   clock signals:                         "clk", "clk_div#", "clk_#x"
--   reset signals:                         "rst", "rst_n"
--   generics:                              "C_*"
--   user defined types:                    "*_TYPE"
--   state machine next state:              "*_ns"
--   state machine current state:           "*_cs"
--   combinatorial signals:                 "*_com"
--   pipelined or register delay signals:   "*_d#"
--   counter signals:                       "*cnt*"
--   clock enable signals:                  "*_ce"
--   internal version of output port:       "*_i"
--   device pins:                           "*_pin"
--   ports:                                 "- Names begin with Uppercase"
--   processes:                             "*_PROCESS"
--   component instantiations:              "<ENTITY_>I_<#|FUNC>"
------------------------------------------------------------------------------

-- DO NOT EDIT BELOW THIS LINE --------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;

library work;
use work.bpm_ddc_pkg.all;
use work.dma_pkg.all;

------------------------------------------------------------------------------
-- Entity section
------------------------------------------------------------------------------
-- Definition of Generics:
--   C_NUM_REG                    -- Number of software accessible registers
--   C_SLV_DWIDTH                 -- Slave interface data bus width
--
-- Definition of Ports:
--   Bus2IP_Clk                   -- Bus to IP clock
--   Bus2IP_Resetn                -- Bus to IP reset
--   Bus2IP_Data                  -- Bus to IP data bus
--   Bus2IP_BE                    -- Bus to IP byte enables
--   Bus2IP_RdCE                  -- Bus to IP read chip enable
--   Bus2IP_WrCE                  -- Bus to IP write chip enable
--   IP2Bus_Data                  -- IP to Bus data bus
--   IP2Bus_RdAck                 -- IP to Bus read transfer acknowledgement
--   IP2Bus_WrAck                 -- IP to Bus write transfer acknowledgement
--   IP2Bus_Error                 -- IP to Bus error response
------------------------------------------------------------------------------

entity user_logic is
  generic
  (
    C_NUM_REG                      		: integer              := 10;
    C_SLV_DWIDTH                   		: integer              := 32
  );
  port
  (
	rst_i								: in std_logic;
	-----------------------------
	-- Signals to/from ADC
	-----------------------------
	adc_clk_i							: in std_logic;
	adc_data_i							: in std_logic_vector(31 downto 0);
	-----------------------------
	-- Signals to/from Delta/Sigma
	-----------------------------
	delta_sigma_x_o						: out std_logic_vector(51 downto 0);
	delta_sigma_y_o                 	: out std_logic_vector(51 downto 0);
	delta_sigma_z_o                 	: out std_logic_vector(51 downto 0);
	delta_sigma_sum_o					: out std_logic_vector(25 downto 0);
	delta_sigma_valid_o			  		: out std_logic;		
	-----------------------------
    -- DMA interface signals
    -----------------------------
	dma_clk               		   		: in  std_logic;
    dma_valid             		   		: out std_logic;
	dma_data              		   		: out std_logic_vector(127 downto 0);
    dma_be                		   		: out std_logic_vector(15 downto 0);
    dma_last              		   		: out std_logic;
    dma_ready             		   		: in  std_logic;
	-----------------------------	
	-- Debug Signals (to Chipscope) 
	-----------------------------
	bpm_ddc_debug_clk_o    				: out std_logic;
    bpm_ddc_debug_data_o          		: out std_logic_vector(1023 downto 0);
    bpm_ddc_debug_trigger_o       		: out std_logic_vector(63 downto 0);
	
	dma_debug_clk_o    					: out std_logic;
	dma_debug_data_o                    : out std_logic_vector(255 downto 0);
	dma_debug_trigger_o                 : out std_logic_vector(15 downto 0);
	
    Bus2IP_Clk                     		: in  std_logic;
    Bus2IP_Resetn                  		: in  std_logic;
    Bus2IP_Data                    		: in  std_logic_vector(C_SLV_DWIDTH-1 downto 0);
    Bus2IP_BE                      		: in  std_logic_vector(C_SLV_DWIDTH/8-1 downto 0);
    Bus2IP_RdCE                    		: in  std_logic_vector(C_NUM_REG-1 downto 0);
    Bus2IP_WrCE                    		: in  std_logic_vector(C_NUM_REG-1 downto 0);
    IP2Bus_Data                    		: out std_logic_vector(C_SLV_DWIDTH-1 downto 0);
    IP2Bus_RdAck                   		: out std_logic;
    IP2Bus_WrAck                   		: out std_logic;
    IP2Bus_Error                   		: out std_logic
  );

  attribute MAX_FANOUT : string;
  attribute SIGIS : string;

  attribute SIGIS of Bus2IP_Clk    		: signal is "CLK";
  attribute SIGIS of Bus2IP_Resetn 		: signal is "RST";

end entity user_logic;

------------------------------------------------------------------------------
-- Architecture section
------------------------------------------------------------------------------

architecture IMP of user_logic is
	-- Registers name
	constant SAMPLES_REG						: natural := 0;
	constant STATUS_REG							: natural := 1;
	
	-- STATUS_REG bit names
	-- Write 0x0 in these bits to clear them
	constant DMA_COMPLETE_BIT					: natural := 0;
	constant DMA_OVF_BIT                        : natural := 1;
	
	constant C_OVF_COUNTER_SIZE					: natural := 10;
    -----------------------------------------------------------------------------------------------
    -- BUS / IP interface signals
    -----------------------------------------------------------------------------------------------
    -- Software accessible registers
    type t_registers is array(0 to C_NUM_REG-1) of std_logic_vector(C_SLV_DWIDTH-1 downto 0);
	-- Register Bank
    signal s_registers                  : t_registers;
	-- DMA status register
	--signal s_dma_status_ctl			: std_logic_vector(C_SLV_DWIDTH-1 downto 0);		
    
    signal slv_reg_write_sel            : std_logic_vector(9 downto 0); -- Not possible to put generic range "C_NUM_REG-1 downto 0" (VHDL limitation)
    signal slv_reg_read_sel             : std_logic_vector(9 downto 0); -- Not possible to put generic range "C_NUM_REG-1 downto 0" (VHDL limitation)
    signal slv_ip2bus_data              : std_logic_vector(C_SLV_DWIDTH-1 downto 0);
    signal slv_read_ack                 : std_logic;
    signal slv_write_ack                : std_logic;

    -- "OR" all elements of a std_logic_vector
    function vector_or (signal arg: in std_logic_vector) return std_logic is
        variable result: std_logic := '0';
    begin
        for i in 0 to arg'length-1 loop
            result := result or arg(i);
        end loop;
        
        return result;
    end function;
	
	-----------------------------------------------------------------------------------------------
    -- IP / user logic interface signals
    -----------------------------------------------------------------------------------------------
	signal s_delta_sigma_x				: std_logic_vector(51 downto 0);
	signal s_delta_sigma_y				: std_logic_vector(51 downto 0);
	signal s_delta_sigma_z				: std_logic_vector(51 downto 0);
	signal s_delta_sigma_sum			: std_logic_vector(25 downto 0);
	signal s_delta_sigma_valid			: std_logic;
	
	signal dma_data_i					: std_logic_vector(127 downto 0);
	signal s_dma_ready					: std_logic;
	
	-- DMA status synch regs	
	signal dma_complete					: std_logic;
	signal s_dma_complete				: std_logic;
	
	signal dma_ovf						: std_logic;
	signal s_dma_ovf                    : std_logic;

begin
	-- Glue logic for delta_sigma signals
	delta_sigma_x_o						<=	s_delta_sigma_x;					
	delta_sigma_y_o						<=	s_delta_sigma_y;		
	delta_sigma_z_o						<=	s_delta_sigma_z;	
	delta_sigma_sum_o					<=  s_delta_sigma_sum;
	delta_sigma_valid_o					<=	s_delta_sigma_valid;
	
    -----------------------------------------------------------------------------------------------
    -- BUS / IP interface
    -----------------------------------------------------------------------------------------------
    -- Bus to IP signals
    slv_reg_write_sel 					<= Bus2IP_WrCE(C_NUM_REG-1 downto 0);
    slv_reg_read_sel  					<= Bus2IP_RdCE(C_NUM_REG-1 downto 0);
    slv_write_ack     					<= vector_or(slv_reg_write_sel);
    slv_read_ack      					<= vector_or(slv_reg_read_sel);

    -- IP to Bus signals
    IP2Bus_Data  <= slv_ip2bus_data when slv_read_ack = '1' else (others => '0');
    IP2Bus_WrAck <= slv_write_ack;
    IP2Bus_RdAck <= slv_read_ack;
    IP2Bus_Error <= '0';

    -- Write to registers
    p_reg_write : process(Bus2IP_Clk) is
    begin
        if rising_edge(Bus2IP_Clk) then
            if Bus2IP_Resetn = '0' then
                s_registers <= (others => (others => '0'));
            else    
                case slv_reg_write_sel is
                    -- Read-write registers
					when "1000000000" => s_registers(SAMPLES_REG) <= Bus2IP_Data;
                    --when std_logic_vector(to_unsigned(2**(C_NUM_REG - 1 - SAMPLES_REG), C_NUM_REG))   => s_registers(SAMPLES_REG) <= Bus2IP_Data;
					when others =>
                end case;
                
                --Read-only registers
				s_registers(STATUS_REG)(DMA_COMPLETE_BIT) <= dma_complete;
				s_registers(STATUS_REG)(DMA_OVF_BIT) <= dma_ovf;
            end if;
        end if; 
    end process;

    -- Read from registers
    p_reg_read : process(slv_reg_read_sel, s_registers) is
    begin
        case slv_reg_read_sel is
            when "1000000000" => slv_ip2bus_data <= s_registers(0);
            when "0100000000" => slv_ip2bus_data <= s_registers(1);
            when "0010000000" => slv_ip2bus_data <= s_registers(2);
            when "0001000000" => slv_ip2bus_data <= s_registers(3);
            when "0000100000" => slv_ip2bus_data <= s_registers(4);
            when "0000010000" => slv_ip2bus_data <= s_registers(5);
            when "0000001000" => slv_ip2bus_data <= s_registers(6);
            when "0000000100" => slv_ip2bus_data <= s_registers(7);
            when "0000000010" => slv_ip2bus_data <= s_registers(8);
            when "0000000001" => slv_ip2bus_data <= s_registers(9);
            --when std_logic_vector(to_unsigned(2**(C_NUM_REG - 1 - register_index), C_NUM_REG)) => slv_ip2bus_data <= s_registers(register_index);
            when others => slv_ip2bus_data <= (others => '0');
        end case;    
    end process; 
  
  -----------------------------------------------------------------------------------------------
  -- IP / user logic interface
  -----------------------------------------------------------------------------------------------
  
  	-- BPM DDC interface
	cmp_bpm_ddc: bpm_ddc_pipe
	port map(
		rst_i							=> rst_i,
		-- Signals to/from ADC
		adc_clk_i						=> adc_clk_i,
		adc_data_i						=> adc_data_i,
		
		-- Signals to/from Delta/Sigma
		delta_sigma_x_o					=> s_delta_sigma_x,
		delta_sigma_y_o					=> s_delta_sigma_y,
		delta_sigma_z_o					=> s_delta_sigma_z,
		delta_sigma_sum					=> s_delta_sigma_sum,	
		bpm_ddc_valid_o					=> s_delta_sigma_valid,
		bpm_ddc_ready_i					=> s_dma_ready,
			
		-- Debug Signals
		bpm_ddc_debug_clk_o     		=> bpm_ddc_debug_clk_o,   
		bpm_ddc_debug_data_o    		=> bpm_ddc_debug_data_o,   
		bpm_ddc_debug_trigger_o 		=> bpm_ddc_debug_trigger_o
	);
	
	-- DMA interface
	cmp_dma_if : dma_if
	generic map
	(
		C_OVF_COUNTER_SIZE				=> C_OVF_COUNTER_SIZE
	)
	port map
	(
		-- External Ports. S2MM (streaming to memory mapped)
		-- Signals syncronized with dma_clk_i
		dma_clk_i             		 	=> dma_clk,   
		dma_valid_o             		=> dma_valid, 
		dma_data_o              		=> dma_data,  
		dma_be_o                		=> dma_be,    
		dma_last_o              		=> dma_last,  
		dma_ready_i             		=> dma_ready, 
		
		-- From data generator
		-- Signals syncronized with data_clk_i
		data_clk_i		               	=> adc_clk_i,
		data_i       	          	  	=> dma_data_i,
		data_valid_i					=> s_delta_sigma_valid,
		data_ready_o					=> s_dma_ready,
		
		-- Capture control
		capture_ctl_i				   	=> s_registers(SAMPLES_REG),
		-- Signals syncronized with data_clk_i. Need synchronization with
		-- Bus clock domain
		dma_complete_o					=> s_dma_complete,
		dma_ovf_o						=> s_dma_ovf,
		
		-- Reset signal
		rst_i						   	=> rst_i,
		
		-- Debug Signals
		dma_debug_clk_o            		=> dma_debug_clk_o,    
		dma_debug_data_o           		=> dma_debug_data_o,   
		dma_debug_trigger_o        		=> dma_debug_trigger_o
	);
	
	-- Consider only the fractional part of each displacement.
	-- Divide each displacement in 32-bit word and fill sign extension
	dma_data_i(127 downto 96)			<= std_logic_vector(RESIZE(signed(s_delta_sigma_sum(25 downto 0)), 32));
	dma_data_i(95 downto 64)			<= std_logic_vector(RESIZE(signed(s_delta_sigma_x(25 downto 0)), 32));
	dma_data_i(63 downto 32)			<= std_logic_vector(RESIZE(signed(s_delta_sigma_y(25 downto 0)), 32));
	dma_data_i(31 downto 0)				<= std_logic_vector(RESIZE(signed(s_delta_sigma_z(25 downto 0)), 32));
	
	-- Synchronize dma_complete_o and dma_ovf_o with bus clock.
	-- Should it employ a more sofisticated sync strategy???
	cmp_dma_status_reg_synch : dma_status_reg_synch
	generic map
	(
		C_STATUS_REG_IDX				=> STATUS_REG
	)
	port map
	(
		-- Bus signals
		bus_clk_i						=> Bus2IP_Clk,
		bus_rst_n_i						=> Bus2IP_Resetn,
		bus_reg_read_sel_i				=> slv_reg_read_sel,
		bus_reg_write_sel_i				=> slv_reg_write_sel,
		bus_2_ip_data_i					=> Bus2IP_Data,
		
		-- DMA synch signals
		dma_complete_i					=> s_dma_complete,
		dma_ovf_i						=> s_dma_ovf,
		
		-- Bus Clock synch signals
		dma_complete_synch_o			=> dma_complete,
		dma_ovf_synch_o					=> dma_ovf
	);

end IMP;
