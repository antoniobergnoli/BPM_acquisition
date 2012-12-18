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

entity single_channel_ddc_pipe is
	port(
		rst_i									: in std_logic;
		
		-- Signals to/from ADC
		adc_clk_i								: in std_logic;
		adc_channel_data_i						: in std_logic_vector(15 downto 0);
		
		-- Signals to/from CORDIC
		cordic_valid_o							: out std_logic;
		ext_ready_i								: in std_logic;
		cordic_data_o							: out std_logic_vector(47 downto 0);
			
		-- Debug Signals
		bpm_ddc_debug_clk_o             		: out std_logic;
		bpm_ddc_debug_data_o            		: out std_logic_vector(255 downto 0);
		bpm_ddc_debug_trigger_o        			: out std_logic_vector(15 downto 0)
	);
end single_channel_ddc_pipe;

architecture rtl of single_channel_ddc_pipe is
	-- Declaration of user signals to be used below
	-- DDS signals
	signal s_dds_valid						: std_logic;
	signal s_dds_data						: std_logic_vector(31 downto 0);
	signal s_dds_ready						: std_logic;
	signal s_dds_cos						: std_logic_vector(15 downto 0);
	-- s_dds_sin is acctually a -sin signal
	signal s_dds_sin						: std_logic_vector(15 downto 0);
	signal dds_valid_d1						: std_logic;
	signal dds_valid_d2						: std_logic;
	signal dds_valid_d3						: std_logic;
	-- Mixer signals
	signal s_mixeri_ce						: std_logic;
	signal s_mixerq_ce						: std_logic;
	signal s_mixeri							: std_logic_vector(23 downto 0);
	signal s_mixerq							: std_logic_vector(23 downto 0);
	-- CIC signals
	signal s_cici_rst_n						: std_logic;
	signal s_cicq_rst_n						: std_logic;
	signal s_cici_data_out					: std_logic_vector(39 downto 0);
	signal s_cici_valid						: std_logic;
	signal s_decimatori_ready				: std_logic;
	signal s_cicq_data_out					: std_logic_vector(39 downto 0);
	signal s_cicq_valid						: std_logic;
	signal s_decimatorq_ready				: std_logic;
	signal s_cici_data_conv_out				: std_logic_vector(23 downto 0);
	signal s_cicq_data_conv_out				: std_logic_vector(23 downto 0);
	-- CORDIC signals
	signal s_cordic_data_in					: std_logic_vector(47 downto 0);
	signal s_cordic_valid_in				: std_logic;
	signal s_cordic_valid					: std_logic;
	signal s_cordic_ready					: std_logic;
	signal s_cordic_data_out				: std_logic_vector(47 downto 0);
	
begin
	-- Debug Data
	bpm_ddc_debug_clk_o    					<= adc_clk_i;
	
	bpm_ddc_debug_trigger_o(15 downto 5)   	<= (others => '0');
	bpm_ddc_debug_trigger_o(4)				<= s_cordic_valid_in;
	bpm_ddc_debug_trigger_o(3)				<= dds_valid_d3;
	bpm_ddc_debug_trigger_o(2)   			<= s_mixerq_ce;
	bpm_ddc_debug_trigger_o(1)   			<= s_mixeri_ce;
	bpm_ddc_debug_trigger_o(0)   			<= s_dds_valid;
	
	bpm_ddc_debug_data_o(255 downto 231) 	<= (others => '0');
	bpm_ddc_debug_data_o(230)				<= s_decimatorq_ready;
	bpm_ddc_debug_data_o(229) 				<= s_decimatori_ready;
	bpm_ddc_debug_data_o(228 downto 181)	<= s_cordic_data_out;
	bpm_ddc_debug_data_o(180 downto 141)	<= s_cicq_data_out(39 downto 0);
	bpm_ddc_debug_data_o(140 downto 101)	<= s_cici_data_out(39 downto 0);
	bpm_ddc_debug_data_o(100 downto 77) 	<= s_mixerq;
	bpm_ddc_debug_data_o(76 downto 53) 		<= s_mixeri;
	bpm_ddc_debug_data_o(52 downto 37) 		<= s_dds_sin;
	bpm_ddc_debug_data_o(36 downto 21) 		<= s_dds_cos;
	bpm_ddc_debug_data_o(20 downto 5) 		<= adc_channel_data_i;
	bpm_ddc_debug_data_o(4)					<= s_cordic_valid_in;
	bpm_ddc_debug_data_o(3)					<= dds_valid_d3;
	bpm_ddc_debug_data_o(2) 				<= s_mixerq_ce;
	bpm_ddc_debug_data_o(1) 				<= s_mixeri_ce;
	bpm_ddc_debug_data_o(0) 				<= s_dds_valid;
	
	------------------------------
	-- 		DDS Stage			--
	------------------------------
	cmp_dds : dds
	port map(
		aclk 								=> adc_clk_i,
		aresetn								=> s_cici_rst_n,
		m_axis_data_tvalid 					=> s_dds_valid,
		m_axis_data_tdata 					=> s_dds_data,
		m_axis_data_tready 					=> s_dds_ready
	);		
			
	-- decouple sin-cos signals		
	s_dds_cos 								<= s_dds_data(15 downto 0);
	s_dds_sin								<= s_dds_data(31 downto 16);
	
	s_dds_ready								<= '1' when s_decimatori_ready = '1' and s_decimatorq_ready = '1' else '0';
		
	-- 3 clock cycles delay to account for the mixer 3-stage pipeline
	p_mixer_valid_delay : process(adc_clk_i)
	begin 			
	if rising_edge(adc_clk_i) then
		if rst_i = '1' then
			dds_valid_d1					<= '0';
			dds_valid_d2					<= '0';      
			dds_valid_d3					<= '0'; 
		elsif s_dds_ready = '1' then
			dds_valid_d1					<= s_dds_valid;
			dds_valid_d2					<= dds_valid_d1;
			dds_valid_d3					<= dds_valid_d2;
		end if;
	end if;
	end process p_mixer_valid_delay;
	
	------------------------------
	-- 		Mixer Stage			--
	------------------------------
	
	-- Mixer has a 3 latency output
	cmp_mixer_i : mixer
	port map(
		clk 								=> adc_clk_i,
		a 									=> adc_channel_data_i,
		b 									=> s_dds_cos,
		ce 									=> s_mixeri_ce,
		p 									=> s_mixeri
	);
	
	s_mixeri_ce								<= s_decimatori_ready;
	--mixeri_o 								<= s_mixeri;
	
	cmp_mixer_q : mixer
	port map(
		clk 								=> adc_clk_i,
		a 									=> adc_channel_data_i,
		b 									=> s_dds_sin,
		ce 									=> s_mixerq_ce,
		p 									=> s_mixerq
	);		
			
	s_mixerq_ce								<= s_decimatorq_ready;
	--mixerq_o 								<= s_mixerq;
	
	------------------------------
	-- 		CIC Stage			--
	------------------------------
	
	cmp_cic_decimator_i : cic_decimator
	port map(
		aclk 								=> adc_clk_i,
		aresetn								=> s_cici_rst_n,
		s_axis_data_tdata 					=> s_mixeri,
		-- Should consider the valid from DDS and account for the latency pipeline!
		s_axis_data_tvalid 					=> dds_valid_d3,			
		s_axis_data_tready 					=> s_decimatori_ready,
		m_axis_data_tdata 					=> s_cici_data_out,
		m_axis_data_tvalid 					=> s_cici_valid,
		m_axis_data_tready 					=> s_cordic_ready,
		event_halted 						=> open
	);
	
	-- Need to adhere to CORDIC input constraints: FIX24_22
	-- (24 word width, 1 bit sign, 1 bit integer part, 22 bit fractional part)
	-- Just shift right to ensure that the number lies within -1 <= number <= 1
	-- Sign Extension
	s_cici_data_conv_out(23 downto 0)		<= s_cici_data_out(39) & s_cici_data_out(39) & s_cici_data_out(38 downto 17);

	s_cici_rst_n							<= not rst_i;
	
	cmp_cic_decimator_q : cic_decimator
	port map(
		aclk 								=> adc_clk_i,
		aresetn								=>	s_cicq_rst_n,
		s_axis_data_tdata 					=> s_mixerq,
		-- Should consider the valid from DDS and account for the latency pipeline!
		s_axis_data_tvalid 					=> dds_valid_d3,			
		s_axis_data_tready 					=> s_decimatorq_ready,
		m_axis_data_tdata 					=> s_cicq_data_out,
		m_axis_data_tvalid 					=> s_cicq_valid,
		m_axis_data_tready 					=> s_cordic_ready,
		event_halted 						=> open
	);
	
	-- Need to adhere to CORDIC input constraints: FIX24_22
	-- (24 word width, 1 bit sign, 1 bit integer part, 22 bit fractional part)
	-- Just shift right to ensure that the number lies within -1 <= number <= 1
	-- Sign Extension	
	s_cicq_data_conv_out(23 downto 0)		<= s_cicq_data_out(39) & s_cicq_data_out(39) & s_cicq_data_out(38 downto 17);
	
	s_cicq_rst_n							<= not rst_i;
	
	------------------------------
	-- 		Cordic Stage		--
	------------------------------
	
	cmp_cordic : cordic
	port map(
		aclk 								=> adc_clk_i,
		s_axis_cartesian_tvalid 			=> s_cordic_valid_in,
		s_axis_cartesian_tready 			=> s_cordic_ready,
		s_axis_cartesian_tdata 				=> s_cordic_data_in,
		m_axis_dout_tvalid 					=> s_cordic_valid,	
		m_axis_dout_tready 					=> ext_ready_i,	
		m_axis_dout_tdata 					=> s_cordic_data_out
	);            

	-- Truncate CIC output to 24 bits
	s_cordic_data_in						<= s_cicq_data_conv_out & s_cici_data_conv_out;
	s_cordic_valid_in						<= '1' when s_cicq_valid = '1' and s_cici_valid = '1' else '0';
	
	-- Glue Logic
	cordic_valid_o							<= s_cordic_valid;
	cordic_data_o	                     	<= s_cordic_data_out;
	
end rtl;