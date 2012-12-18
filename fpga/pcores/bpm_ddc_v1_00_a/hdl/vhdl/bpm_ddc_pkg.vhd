library ieee;
use ieee.std_logic_1164.all;

--package bpm_ddc_pkg is

--end bpm_ddc_pkg;

package bpm_ddc_pkg is

	------------------------------
	-- 		Components			--
	------------------------------

	component bpm_ddc_pipe is
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
	end component bpm_ddc_pipe;
	
	component single_channel_ddc_pipe is
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
	end component single_channel_ddc_pipe;
	
	component dds
	port (
		aclk 									: in std_logic;
		aresetn 								: in std_logic;
		m_axis_data_tvalid 						: out std_logic;
		m_axis_data_tready 						: in std_logic;
		m_axis_data_tdata 						: out std_logic_vector(31 downto 0)
	);
	end component dds;
	
	component mixer
	port (
		clk 							: in std_logic;
		a 								: in std_logic_vector(15 downto 0);
		b 								: in std_logic_vector(15 downto 0);
		ce 								: in std_logic;
		p 								: out std_logic_vector(23 downto 0)
	);
	end component mixer;

	component cic_decimator is
	port (
		aclk 							: in std_logic;
		aresetn 						: in std_logic;
		s_axis_data_tdata 				: in std_logic_vector(23 downto 0);
		s_axis_data_tvalid 				: in std_logic;
		s_axis_data_tready 				: out std_logic;
		m_axis_data_tdata 				: out std_logic_vector(39 downto 0);
		m_axis_data_tvalid 				: out std_logic;
		m_axis_data_tready 				: in std_logic;
		event_halted 					: out std_logic
	);
	end component cic_decimator;
	
	component cordic is
	port (
		aclk 							: in std_logic;
		s_axis_cartesian_tvalid 		: in std_logic;
		s_axis_cartesian_tready 		: out std_logic;
		s_axis_cartesian_tdata 			: in std_logic_vector(47 downto 0);
		m_axis_dout_tvalid 				: out std_logic;
		m_axis_dout_tready 				: in std_logic;
		m_axis_dout_tdata 				: out std_logic_vector(47 downto 0)
	);
	end component cordic;
	
	component delta_over_sigma is
    generic(
		-- Fixed in 24!
		G_DATAIN_WIDTH    				: integer := 24
	);
	port
	(
		i_clk        					: in  std_logic;
		i_rst        					: in  std_logic;
		i_a          					: in  std_logic_vector(G_DATAIN_WIDTH-1 downto 0);
		i_b          					: in  std_logic_vector(G_DATAIN_WIDTH-1 downto 0);
		i_c          					: in  std_logic_vector(G_DATAIN_WIDTH-1 downto 0);
		i_d          					: in  std_logic_vector(G_DATAIN_WIDTH-1 downto 0);
		o_x          					: out std_logic_vector(2*(G_DATAIN_WIDTH+1)+1 downto 0);
		o_y          					: out std_logic_vector(2*(G_DATAIN_WIDTH+1)+1 downto 0);
		o_z          					: out std_logic_vector(2*(G_DATAIN_WIDTH+1)+1 downto 0);
		o_sum        					: out std_logic_vector(G_DATAIN_WIDTH+1 downto 0);
		i_valid      					: in  std_logic;
		o_rdy        					: out std_logic;
							
		o_valid		 					: out std_logic;
		i_rdy		 					: in std_logic;
							
		o_err        					: out std_logic
	);
    end component delta_over_sigma;

end bpm_ddc_pkg;
