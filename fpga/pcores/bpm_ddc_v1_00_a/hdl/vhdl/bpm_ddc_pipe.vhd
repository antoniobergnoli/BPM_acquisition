------------------------------------------------------------------------------
--																			--
-- company name, division and the name of the design 						--
-- 																			--
------------------------------------------------------------------------------
--
-- 		unit name: 	<full name> (<shortname / entity name>)
--
-- 		author: <author name> (<email>)
--
-- 		date: $Date:: $:
--
-- 		version: $Rev:: $:
--
-- 		description: <file content, behaviour, purpose, special usage notes...>
-- 				<further description>
--
-- 		dependencies: <entity name>, ...
--
-- 		references: <reference one>
-- 						<reference two> ...
--
-- 		modified by: $Author:: $:
------------------------------------------------------------------------------
-- 		last changes: <date> <initials> <log>
-- 			<extended description>
------------------------------------------------------------------------------ 
--		TODO: <next thing to do>
-- 			<another thing to do>
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

LIBRARY XilinxCoreLib;

-- BPM Filter components declarations
library work;
use work.bpm_ddc_pkg.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity bpm_ddc_pipe is
	port(
		rst_i									: in std_logic;
		-- Signals to/from ADC
		adc_clk_i								: in std_logic;
		adc_data_i								: in std_logic_vector(31 downto 0);
		
		-- Signals to/from Delta/Sigma
		delta_sigma_x_o							: out std_logic_vector(51 downto 0);	
		delta_sigma_y_o							: out std_logic_vector(51 downto 0);
		delta_sigma_z_o							: out std_logic_vector(51 downto 0);
		delta_sigma_sum							: out std_logic_vector(25 downto 0);
		bpm_ddc_valid_o							: out std_logic;
		bpm_ddc_ready_i							: in std_logic;
			
		-- Debug Signals
		bpm_ddc_debug_clk_o             		: out std_logic;
		bpm_ddc_debug_data_o            		: out std_logic_vector(1023 downto 0);
		bpm_ddc_debug_trigger_o        			: out std_logic_vector(63 downto 0)
	);
end bpm_ddc_pipe;

architecture rtl of bpm_ddc_pipe is
	-- ADC signals
	signal s_adc_data_cha						: std_logic_vector(15 downto 0);
	signal s_adc_data_chb						: std_logic_vector(15 downto 0);
	-- CORDIC signals
	signal s_cordic_cha_data_out				: std_logic_vector(47 downto 0);
	signal s_cordic_chb_data_out				: std_logic_vector(47 downto 0);
	signal s_cordic_cha_valid					: std_logic;
	signal s_cordic_chb_valid					: std_logic;
	--Delta/Sigma signals
	signal s_delta_sigma_ready					: std_logic;
	signal s_delta_sigma_valid_in				: std_logic;
	signal s_delta_sigma_x						: std_logic_vector(51 downto 0);
	signal s_delta_sigma_y						: std_logic_vector(51 downto 0);
	signal s_delta_sigma_z						: std_logic_vector(51 downto 0);
	signal s_delta_sigma_sum					: std_logic_vector(25 downto 0);
	signal s_delta_sigma_valid_out				: std_logic;
	
	-- Debug signals
	signal s_cha_debug_clk						: std_logic;		
	signal s_cha_debug_data	                    : std_logic_vector(255 downto 0);
	signal s_cha_debug_trigger                  : std_logic_vector(15 downto 0);

	signal s_chb_debug_clk						: std_logic;
	signal s_chb_debug_data                     : std_logic_vector(255 downto 0);
	signal s_chb_debug_trigger                  : std_logic_vector(15 downto 0);
	
	
begin
	-- Debug Clock
	bpm_ddc_debug_clk_o    					<= s_cha_debug_clk;
	
	-- Debug Trigger
	bpm_ddc_debug_trigger_o(63 downto 32)	<= (others => '0');
	bpm_ddc_debug_trigger_o(31 downto 16)	<= s_cha_debug_trigger;
	bpm_ddc_debug_trigger_o(15 downto 0)	<= s_chb_debug_trigger;
	
	-- Debug Data
	bpm_ddc_debug_data_o(1023 downto 697)	<= (others => '0');
	bpm_ddc_debug_data_o(696 downto 671)	<= s_delta_sigma_sum;
	bpm_ddc_debug_data_o(670 downto 619) 	<= s_delta_sigma_x;
	bpm_ddc_debug_data_o(618 downto 567) 	<= s_delta_sigma_y;
	bpm_ddc_debug_data_o(566 downto 515) 	<= s_delta_sigma_z;	
	
	bpm_ddc_debug_data_o(514)				<= s_delta_sigma_valid_out;
	bpm_ddc_debug_data_o(513)				<= s_delta_sigma_valid_in;
	bpm_ddc_debug_data_o(512)             	<= s_delta_sigma_ready;

	bpm_ddc_debug_data_o(511 downto 256)	<= s_cha_debug_data;
	bpm_ddc_debug_data_o(255 downto 0)		<= s_chb_debug_data;
	
	-- ADC decoupling
	s_adc_data_cha							<= adc_data_i(31 downto 16);
	s_adc_data_chb							<= adc_data_i(15 downto 0);

	-- Filter Pipeline Instantiation
	cmp_cha_ddc_pipe : single_channel_ddc_pipe
	port map(
		rst_i								=> rst_i,
		
		-- Signals to/from ADC
		adc_clk_i							=> adc_clk_i,
		adc_channel_data_i					=> s_adc_data_cha,
		
		-- Signals to/from CORDIC
		cordic_valid_o						=> s_cordic_cha_valid,
		ext_ready_i							=> s_delta_sigma_ready,
		cordic_data_o						=> s_cordic_cha_data_out,
			
		-- Debug Signals
		bpm_ddc_debug_clk_o             	=> s_cha_debug_clk,
		bpm_ddc_debug_data_o            	=> s_cha_debug_data,
		bpm_ddc_debug_trigger_o        		=> s_cha_debug_trigger
	);
	
	cmp_chb_ddc_pipe : single_channel_ddc_pipe
	port map(
		rst_i								=> rst_i,
		
		-- Signals to/from ADC
		adc_clk_i							=> adc_clk_i,
		adc_channel_data_i					=> s_adc_data_chb,
		
		-- Signals to/from CORDIC
		cordic_valid_o						=> s_cordic_chb_valid,
		ext_ready_i							=> s_delta_sigma_ready,
		cordic_data_o						=> s_cordic_chb_data_out,
			
		-- Debug Signals
		bpm_ddc_debug_clk_o             	=> s_chb_debug_clk,
		bpm_ddc_debug_data_o            	=> s_chb_debug_data,
		bpm_ddc_debug_trigger_o        		=> s_chb_debug_trigger
	);
	
	cmp_delta_sigma : delta_over_sigma
	generic map(
		-- Avoid changing because the fixed point diveder core is "hardcoded" by core generator
		G_DATAIN_WIDTH    => 24
	)
	port map(
		i_clk           						=> adc_clk_i,
		i_rst           						=> rst_i,
		-- Input only the magnitude of the CORDIC output signal
		i_a             						=> s_cordic_cha_data_out(23 downto 0),
		i_b             						=> s_cordic_cha_data_out(23 downto 0),
		i_c             						=> s_cordic_chb_data_out(23 downto 0),
		i_d             						=> s_cordic_chb_data_out(23 downto 0),
		o_x             						=> s_delta_sigma_x,
		o_y             						=> s_delta_sigma_y,
		o_z             						=> s_delta_sigma_z,
		o_sum           						=> s_delta_sigma_sum,
		i_valid         						=> s_delta_sigma_valid_in,
		o_rdy           						=> s_delta_sigma_ready,
		         						
		o_valid									=> s_delta_sigma_valid_out,
		i_rdy									=> bpm_ddc_ready_i,

		o_err  									=> open
	);             

	-- Glue Logic
	delta_sigma_x_o								<= s_delta_sigma_x;
	delta_sigma_y_o								<= s_delta_sigma_y;
	delta_sigma_z_o								<= s_delta_sigma_z;
	delta_sigma_sum								<= s_delta_sigma_sum;
	bpm_ddc_valid_o								<= s_delta_sigma_valid_out;
		
	s_delta_sigma_valid_in						<= '1' when s_cordic_cha_valid = '1' and s_cordic_chb_valid = '1' else '0';	
	
end rtl;