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

entity bpm_ddc is
	port(
		-- Signals to/from ADC
		adc_clk_i								: in std_logic;
		adc_data_i								: in std_logic_vector(15 downto 0);
		
		-- Signals to/from ADC-DDs Multiplier
		mixeri_o								: out std_logic_vector(31 downto 0);
		mixerq_o								: out std_logic_vector(31 downto 0);
			
		-- Debug Signals
		bpm_ddc_debug_clk_i             		: out std_logic;
		bpm_ddc_debug_data_o            		: out std_logic_vector(63 downto 0);
		bpm_ddc_debug_trigger_o        			: out std_logic_vector(7 downto 0)
	);
end bpm_ddc;

architecture rtl of bpm_ddc is
	-- Declaration of user signals to be used below
	-- DDS signals
	signal s_dds_valid						: std_logic;
	signal s_dds_data						: std_logic_vector(31 downto 0);
	signal s_dds_cos						: std_logic_vector(15 downto 0);
	-- s_dds_sin is acctually a -sin signal
	signal s_dds_sin						: std_logic_vector(15 downto 0);
	-- ADC-DDS multiplier signals
	signal s_mixeri_ce					: std_logic;
	signal s_mixerq_ce					: std_logic;
	signal s_mixeri						: std_logic_vector(31 downto 0);
	signal s_mixerq						: std_logic_vector(31 downto 0);
	
	-- CIC signals
	
begin
	-- Debug Data
	bpm_ddc_debug_clk_i    					<= adc_clk_i;
	
	bpm_ddc_debug_trigger_o(7 downto 3)   	<= (others => '0');
	bpm_ddc_debug_trigger_o(2)   			<= s_mixerq_ce;
	bpm_ddc_debug_trigger_o(1)   			<= s_mixeri_ce;
	bpm_ddc_debug_trigger_o(0)   			<= s_dds_valid;
	
	bpm_ddc_debug_data_o(63 downto 35) 		<= (others => '0');
	bpm_ddc_debug_data_o(34 downto 19) 		<= s_dds_sin;
	bpm_ddc_debug_data_o(18 downto 3) 		<= s_dds_cos;
	bpm_ddc_debug_data_o(2) 				<= s_mixerq_ce;
	bpm_ddc_debug_data_o(1) 				<= s_mixeri_ce;
	bpm_ddc_debug_data_o(0) 				<= s_dds_valid;

	-- Filter Pipeline Instantiation
	cmp_dds : dds
	port map(
		aclk 								=> adc_clk_i,
		m_axis_data_tvalid 					=> s_dds_valid,
		m_axis_data_tdata 					=> s_dds_data
	);		
			
	-- decouple sin-cos signals		
	s_dds_cos 								<= s_dds_data(15 downto 0);
	s_dds_sin								<= s_dds_data(31 downto 16);
	
	cmp_mixer_i : mixer
	port map(
		clk 								=> adc_clk_i,
		a 									=> adc_data_i,
		b 									=> s_dds_cos,
		ce 									=> s_mixeri_ce,
		p 									=> s_mixeri
	);
	
	s_mixeri_ce								<= '1' when s_dds_valid = '1' else '0';
	mixeri_o 								<= s_mixeri;
	
	cmp_mixer_q : mixer
	port map(
		clk 								=> adc_clk_i,
		a 									=> adc_data_i,
		b 									=> s_dds_sin,
		ce 									=> s_mixerq_ce,
		p 									=> s_mixerq
	);		
			
	s_mixerq_ce								<= '1' when s_dds_valid = '1' else '0';
	mixerq_o 								<= s_mixerq;

end rtl;

