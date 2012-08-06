library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity USER_LOGIC_TB is				-- entity declaration
end USER_LOGIC_TB;

architecture TB of USER_LOGIC_TB is

	-- 61.44 MHz clock
	constant CLOCK_PERIOD 						: time := 16.28 ns;
	constant IP_WIDTH    						: integer := 16; -- Width of the input data
	
	signal g_end_simulation          		: boolean   := false; -- Set to true to halt the simulation
	signal SIN_DATA								: std_logic_vector(15 downto 0);

	signal RST_I									: std_logic := '0';
	signal ADC_CLK_I								: std_logic := '0';
	signal ADC_DATA_I					         : std_logic_vector(31 downto 0);
	                                       												
	signal DELTA_SIGMA_X_O						: std_logic_vector(25 downto 0);
	signal DELTA_SIGMA_Y_O						: std_logic_vector(25 downto 0);
	signal DELTA_SIGMA_Z_O						: std_logic_vector(25 downto 0);
	signal DELTA_SIGMA_VALID_O					: std_logic;	
		                                                       
	signal BPM_DDC_DEBUG_CLK_O             : std_logic;
	signal BPM_DDC_DEBUG_DATA_O            : std_logic_vector(1023 downto 0);
	signal BPM_DDC_DEBUG_TRIGGER_O         : std_logic_vector(63 downto 0);
	
	component bpm_ddc_pipe is
	port(
		-- Signals to/from ADC
		rst_i											: in std_logic;
		-- Signals to/from ADC
		adc_clk_i									: in std_logic;
		adc_data_i									: in std_logic_vector(31 downto 0);
		
		-- Signals to/from Mixer
		--mixeri_o									: out std_logic_vector(23 downto 0);
		--mixerq_o									: out std_logic_vector(23 downto 0);
		-- Signals to/from Delta/Sigma
		delta_sigma_x_o							: out std_logic_vector(25 downto 0);	
		delta_sigma_y_o							: out std_logic_vector(25 downto 0);
		delta_sigma_z_o							: out std_logic_vector(25 downto 0);
		delta_sigma_valid_o						: out std_logic;
			
		-- Debug Signals
		bpm_ddc_debug_clk_o             		: out std_logic;
		bpm_ddc_debug_data_o            		: out std_logic_vector(1023 downto 0);
		bpm_ddc_debug_trigger_o        		: out std_logic_vector(63 downto 0)
	);
	end component bpm_ddc_pipe;
	
	-- Functions
	function calculate_next_input_sample(sample_number : in integer) return std_logic_vector is
    variable A      : real  := 1.0;   -- Amplitude for wave
    variable F      : real  := 100.0;   -- Frequency for wave
    variable P      : real  := 0.0;   -- Phase for wave
    variable theta  : real;

    variable y      : real;     -- The calculated value as a real
    variable y_int  : integer;  -- The calculated value as an integer
    variable result : std_logic_vector(IP_WIDTH-1 downto 0);
       
    variable number_of_samples : real := 100.0 * real(47);

  begin
    theta  := (2.0 * MATH_PI * F * real(sample_number mod integer(number_of_samples))) / number_of_samples;
 
    y      := A * sin(theta + P);
    y_int  := integer(round(y * real(2**(IP_WIDTH-2))));
    result := std_logic_vector(to_signed(y_int, IP_WIDTH));

    return result;
  end function calculate_next_input_sample;
	
	begin

	cmp_bpm_ddc: bpm_ddc_pipe
	port map
	(
		-- Signals to/from ADC
		rst_i											=>	RST_I,									
		-- Signals to/from ADC      
		adc_clk_i									=> ADC_CLK_I,					
		adc_data_i									=> ADC_DATA_I,					
		
		-- Signals to/from Delta/Sigma         
		delta_sigma_x_o							=> DELTA_SIGMA_X_O,			
		delta_sigma_y_o							=> DELTA_SIGMA_Y_O,			
		delta_sigma_z_o							=> DELTA_SIGMA_Z_O,			
		delta_sigma_valid_o						=> DELTA_SIGMA_VALID_O,		
			                                    	
		-- Debug Signals                      
		bpm_ddc_debug_clk_o           		=> BPM_DDC_DEBUG_CLK_O,     
		bpm_ddc_debug_data_o          		=> BPM_DDC_DEBUG_DATA_O,    
		bpm_ddc_debug_trigger_o       		=> BPM_DDC_DEBUG_TRIGGER_O 
	);
	
	-- Clock process
  CLOCK_PROC : process
  begin
    while g_end_simulation = false loop
      ADC_CLK_I <= '0';
      wait for CLOCK_PERIOD/2;
      ADC_CLK_I <= '1';
      wait for CLOCK_PERIOD/2;
    end loop;

    report "End of test (not a failure, just ending simulation)." severity failure;
    wait;
  end process CLOCK_PROC;

	TB_PROC : process
	begin
		RST_I <= '1';
		wait for 8*CLOCK_PERIOD;
		RST_I <= '0';
		
		for i in 1 to 600 loop
			ADC_DATA_I <= calculate_next_input_sample(i) & calculate_next_input_sample(i);
			wait for CLOCK_PERIOD;		
		end loop;
				
		wait for 600*CLOCK_PERIOD;	
		g_end_simulation <= true;
		wait;
	end process TB_PROC;

end TB;