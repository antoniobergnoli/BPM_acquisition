library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;

library work;
use work.fmc150_pkg.all;
use work.dma_pkg.all;

entity user_logic is
generic
(
    C_NUM_REG           : integer := 10;
    C_SLV_DWIDTH        : integer := 32
);
port
(
    -----------------------------
    -- BUS / IP interface signals
    -----------------------------
    Bus2IP_Clk          : in  std_logic;
    Bus2IP_Resetn       : in  std_logic;
    Bus2IP_Data         : in  std_logic_vector(C_SLV_DWIDTH-1 downto 0);
    Bus2IP_BE           : in  std_logic_vector(C_SLV_DWIDTH/8-1 downto 0);
    Bus2IP_RdCE         : in  std_logic_vector(C_NUM_REG-1 downto 0);
    Bus2IP_WrCE         : in  std_logic_vector(C_NUM_REG-1 downto 0);
    IP2Bus_Data         : out std_logic_vector(C_SLV_DWIDTH-1 downto 0);
    IP2Bus_RdAck        : out std_logic;
    IP2Bus_WrAck        : out std_logic;
    IP2Bus_Error        : out std_logic;
	
	-----------------------------
    -- DMA interface signals
    -----------------------------
	dma_clk               		   : in  std_logic;
    dma_valid             		   : out std_logic;
	dma_data              		   : out std_logic_vector(31 downto 0);
    dma_be                		   : out std_logic_vector(3 downto 0);
    dma_last              		   : out std_logic;
    dma_ready             		   : in  std_logic;

    -----------------------------
    -- External ports
    -----------------------------
    --Clock/Data connection to ADC on FMC150 (ADS62P49)
    adc_clk_ab_p        : in  std_logic;
    adc_clk_ab_n        : in  std_logic;
    adc_cha_p           : in  std_logic_vector(6 downto 0);
    adc_cha_n           : in  std_logic_vector(6 downto 0);
    adc_chb_p           : in  std_logic_vector(6 downto 0);
    adc_chb_n           : in  std_logic_vector(6 downto 0);

    --Clock/Data connection to DAC on FMC150 (DAC3283)
    dac_dclk_p          : out std_logic;
    dac_dclk_n          : out std_logic;
    dac_data_p          : out std_logic_vector(7 downto 0);
    dac_data_n          : out std_logic_vector(7 downto 0);
    dac_frame_p         : out std_logic;
    dac_frame_n         : out std_logic;
    txenable            : out std_logic;
    
    --Clock/Trigger connection to FMC150
    clk_to_fpga_p       : in  std_logic;
    clk_to_fpga_n       : in  std_logic;
    ext_trigger_p       : in  std_logic;
    ext_trigger_n       : in  std_logic;
    
    -- Control signals from/to FMC150
    --Serial Peripheral Interface (SPI)
    spi_sclk            : out std_logic; -- Shared SPI clock line
    spi_sdata           : out std_logic; -- Shared SPI data line
    
    -- ADC specific signals
    adc_n_en            : out std_logic; -- SPI chip select
    adc_sdo             : in  std_logic; -- SPI data out
    adc_reset           : out std_logic; -- SPI reset
    
    -- CDCE specific signals
    cdce_n_en           : out std_logic; -- SPI chip select
    cdce_sdo            : in  std_logic; -- SPI data out
    cdce_n_reset        : out std_logic;
    cdce_n_pd           : out std_logic;
    cdce_ref_en         : out std_logic;
    cdce_pll_status     : in  std_logic;
    
    -- DAC specific signals
    dac_n_en            : out std_logic; -- SPI chip select
    dac_sdo             : in  std_logic; -- SPI data out
    
    -- Monitoring specific signals
    mon_n_en            : out std_logic; -- SPI chip select
    mon_sdo             : in  std_logic; -- SPI data out
    mon_n_reset         : out std_logic;
    mon_n_int           : in  std_logic;
    
    --FMC Present status
    prsnt_m2c_l         : in  std_logic;

    rst                 : in  std_logic;
    clk_100Mhz          : in  std_logic;
    clk_200Mhz          : in  std_logic;
    
	-- Signals routed to DMA interface now
    adc_dout_o          : out std_logic_vector(31 downto 0);
    clk_adc_o           : out std_logic;
	
	-- Up Status
	up_status			: out std_logic_vector(3 downto 0);
	
	-- Debug Signals (to Chipscope)
	debug_clk           : out std_logic;
    debug_data          : out std_logic_vector(255 downto 0);
    debug_trigger       : out std_logic_vector(15 downto 0)
);

attribute MAX_FANOUT : string;
attribute SIGIS : string;
attribute SIGIS of Bus2IP_Clk    : signal is "CLK";
attribute SIGIS of Bus2IP_Resetn : signal is "RST";

end entity user_logic;


architecture rtl of user_logic is
    constant FLAGS_PULSE_0                      : natural := 0;
    constant FLAGS_IN_0                         : natural := 1;
    constant FLAGS_OUT_0                        : natural := 2;
    constant ADDR                               : natural := 3;
    constant DATAIN                             : natural := 4;
    constant DATAOUT                            : natural := 5;
    constant CHIPSELECT                         : natural := 6;
    constant ADC_DELAY                          : natural := 7;
	constant SAMPLES_REG						: natural := 8;
	constant STATUS_REG							: natural := 9;
	
	-- STATUS_REG bit names
	-- Write 0x0 in these bits to clear them
	constant DMA_COMPLETE_BIT					: natural := 0;
	constant DMA_OVF_BIT                        : natural := 1;
    
    constant FLAGS_OUT_0_SPI_BUSY               : natural := 0;
    constant FLAGS_OUT_0_CDCE_PLL_STATUS        : natural := 1;
    constant FLAGS_OUT_0_FPGA_ADC_CLK_LOCKED    : natural := 2;
    constant FLAGS_OUT_0_FMC_PRESENT            : natural := 3;
    
    constant CHIPSELECT_CDCE72010               : natural := 0;
    constant CHIPSELECT_ADS62P49                : natural := 1;
    constant CHIPSELECT_DAC3283                 : natural := 2;
    constant CHIPSELECT_AMC7823                 : natural := 3;
    
    constant FLAGS_IN_0_SPI_RW                  : natural := 0;
    constant FLAGS_IN_0_EXTERNAL_CLOCK          : natural := 1;

    -----------------------------------------------------------------------------------------------
    -- BUS / IP interface signals
    -----------------------------------------------------------------------------------------------
    -- Software accessible registers
    type t_registers is array(0 to C_NUM_REG-1) of std_logic_vector(C_SLV_DWIDTH-1 downto 0);
    signal s_registers                  : t_registers;
    
    signal slv_reg_write_sel            : std_logic_vector(9 downto 0); -- Not possible to put generic range "C_NUM_REG-1 downto 0" (VHDL limitation)
    signal slv_reg_read_sel             : std_logic_vector(9 downto 0); -- Not possible to put generic range "C_NUM_REG-1 downto 0" (VHDL limitation)
    signal slv_ip2bus_data              : std_logic_vector(C_SLV_DWIDTH-1 downto 0);
    signal slv_read_ack                 : std_logic;
    signal slv_write_ack                : std_logic;
	
	-- DMA IF Signals
	signal s_dma_if_valid_in			: std_logic;

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
    signal s_core2usr_fmc150_ctrl       : t_fmc150_ctrl_in;
    signal s_usr2core_fmc150_ctrl       : t_fmc150_ctrl_out;
    
    signal s_clk_out_pulse_sync         : std_logic_vector(C_SLV_DWIDTH-1 downto 0);
    signal s_pulse_register_sync        : std_logic_vector(C_SLV_DWIDTH-1 downto 0);

    signal s_adc_delay_update           : std_logic;
    
    signal s_adc_str_cntvaluein         : std_logic_vector(4 downto 0);
    signal s_adc_cha_cntvaluein         : std_logic_vector(4 downto 0);
    signal s_adc_chb_cntvaluein         : std_logic_vector(4 downto 0);
    
    signal s_mmcm_adc_locked            : std_logic;
    
    signal s_odata                      : std_logic_vector(C_SLV_DWIDTH-1 downto 0);
    signal s_busy                       : std_logic;
	
	signal s_adc_dout         			: std_logic_vector(31 downto 0);
    signal s_clk_adc         			: std_logic;
		
	-- DMA status synch regs	
	signal dma_complete					: std_logic;
	signal s_dma_complete				: std_logic;
	
	signal dma_ovf						: std_logic;
	signal s_dma_ovf                    : std_logic;
    
begin
	-- Glue logic
	adc_dout_o <= s_adc_dout;
	clk_adc_o <= s_clk_adc;

    -----------------------------------------------------------------------------------------------
    -- BUS / IP interface
    -----------------------------------------------------------------------------------------------
    -- Bus to IP signals
    slv_reg_write_sel <= Bus2IP_WrCE(C_NUM_REG-1 downto 0);
    slv_reg_read_sel  <= Bus2IP_RdCE(C_NUM_REG-1 downto 0);
    slv_write_ack     <= vector_or(slv_reg_write_sel);
    slv_read_ack      <= vector_or(slv_reg_read_sel);

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
                    when std_logic_vector(to_unsigned(2**(C_NUM_REG - 1 - FLAGS_PULSE_0), C_NUM_REG))   => s_registers(FLAGS_PULSE_0)   <= Bus2IP_Data;
                    when std_logic_vector(to_unsigned(2**(C_NUM_REG - 1 - FLAGS_IN_0), C_NUM_REG))      => s_registers(FLAGS_IN_0)      <= Bus2IP_Data;
                    when std_logic_vector(to_unsigned(2**(C_NUM_REG - 1 - ADDR), C_NUM_REG))            => s_registers(ADDR)            <= Bus2IP_Data;
                    when std_logic_vector(to_unsigned(2**(C_NUM_REG - 1 - DATAIN), C_NUM_REG))          => s_registers(DATAIN)          <= Bus2IP_Data;
                    when std_logic_vector(to_unsigned(2**(C_NUM_REG - 1 - CHIPSELECT), C_NUM_REG))      => s_registers(CHIPSELECT)      <= Bus2IP_Data;
                    when std_logic_vector(to_unsigned(2**(C_NUM_REG - 1 - ADC_DELAY), C_NUM_REG))       => s_registers(ADC_DELAY)       <= Bus2IP_Data;
                    when std_logic_vector(to_unsigned(2**(C_NUM_REG - 1 - SAMPLES_REG), C_NUM_REG))     => s_registers(SAMPLES_REG)     <= Bus2IP_Data;
		
                    --when "1000000000" => s_registers(FLAGS_PULSE_0) <= Bus2IP_Data;
                    --when "0100000000" => s_registers(FLAGS_IN_0)    <= Bus2IP_Data;
                    --when "0001000000" => s_registers(ADDR)          <= Bus2IP_Data;
                    --when "0000100000" => s_registers(DATAIN)        <= Bus2IP_Data;
                    --when "0000001000" => s_registers(CHIPSELECT)    <= Bus2IP_Data;
                    --when "0000000100" => s_registers(ADC_DELAY)     <= Bus2IP_Data;
                    
                    -- Pulse registers (reset to 0x0 when no write has been demanded)
                    when others => s_registers(FLAGS_PULSE_0) <= (others => '0');
                end case;
                
                -- Read-only registers
                s_registers(DATAOUT) <= s_odata;
                s_registers(FLAGS_OUT_0)(FLAGS_OUT_0_SPI_BUSY) <= s_busy;
                s_registers(FLAGS_OUT_0)(FLAGS_OUT_0_CDCE_PLL_STATUS) <= cdce_pll_status;
                s_registers(FLAGS_OUT_0)(FLAGS_OUT_0_FPGA_ADC_CLK_LOCKED) <= s_mmcm_adc_locked;
                s_registers(FLAGS_OUT_0)(FLAGS_OUT_0_FMC_PRESENT) <= prsnt_m2c_l;
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
    -- IP / user logic interface (FIXME: melhorar organização do código)
    -----------------------------------------------------------------------------------------------
	
	-- UP Status
	p_up_status : process(Bus2IP_Clk) is
	begin
		if rising_edge(Bus2IP_Clk) then
            if Bus2IP_Resetn = '0' then
                up_status 		<= (others => '0');
            else
				up_status 		<= prsnt_m2c_l & s_mmcm_adc_locked & cdce_pll_status & s_busy;
			end if;
		end if;
	end process;
	
    s_clk_out_pulse_sync(0) <= clk_100Mhz;
    
    gen_pulse_register_sync :  for i in 0 to (C_SLV_DWIDTH/2)-1 generate
    
        cmp_adc_delay_update : pulse2pulse
        port map
        (
            in_clk      => Bus2IP_Clk,                                  
            out_clk     => s_clk_out_pulse_sync(i),
            rst         => not Bus2IP_Resetn,
            pulsein     => s_registers(FLAGS_PULSE_0)(i),
            inbusy      => open,
            pulseout    => s_pulse_register_sync(i)
        );
    
    end generate;
    
    s_adc_delay_update <= s_pulse_register_sync(0);
    
    cmp_fmc150_testbench: fmc150_testbench
    port map
    (
        rst                     => rst,
        clk_100Mhz              => clk_100Mhz,
        clk_200Mhz              => clk_200Mhz,

        adc_clk_ab_p            => adc_clk_ab_p,
        adc_clk_ab_n            => adc_clk_ab_n,
        adc_cha_p               => adc_cha_p,
        adc_cha_n               => adc_cha_n,
        adc_chb_p               => adc_chb_p,
        adc_chb_n               => adc_chb_n,
        dac_dclk_p              => dac_dclk_p,
        dac_dclk_n              => dac_dclk_n,
        dac_data_p              => dac_data_p,
        dac_data_n              => dac_data_n,
        dac_frame_p             => dac_frame_p,
        dac_frame_n             => dac_frame_n,
        txenable                => txenable,
        clk_to_fpga_p           => clk_to_fpga_p,
        clk_to_fpga_n           => clk_to_fpga_n,
        ext_trigger_p           => ext_trigger_p,
        ext_trigger_n           => ext_trigger_n,
        spi_sclk                => spi_sclk,
        spi_sdata               => spi_sdata,
        adc_n_en                => adc_n_en,
        adc_sdo                 => adc_sdo,
        adc_reset               => adc_reset,
        cdce_n_en               => cdce_n_en,
        cdce_sdo                => cdce_sdo,
        cdce_n_reset            => cdce_n_reset,
        cdce_n_pd               => cdce_n_pd,
        ref_en                  => cdce_ref_en,
        dac_n_en                => dac_n_en,
        dac_sdo                 => dac_sdo,
        mon_n_en                => mon_n_en,
        mon_sdo                 => mon_sdo,
        mon_n_reset             => mon_n_reset,
        mon_n_int               => mon_n_int,

        pll_status              => cdce_pll_status,
        mmcm_adc_locked_o       => s_mmcm_adc_locked,
        odata                   => s_odata,
        busy                    => s_busy,
        prsnt_m2c_l             => prsnt_m2c_l,
       
        rd_n_wr                 => s_registers(FLAGS_IN_0)(FLAGS_IN_0_SPI_RW),
        addr                    => s_registers(ADDR)(15 downto 0),
        idata                   => s_registers(DATAIN),
        cdce72010_valid         => s_registers(CHIPSELECT)(CHIPSELECT_CDCE72010),
        ads62p49_valid          => s_registers(CHIPSELECT)(CHIPSELECT_ADS62P49),
        dac3283_valid           => s_registers(CHIPSELECT)(CHIPSELECT_DAC3283),
        amc7823_valid           => s_registers(CHIPSELECT)(CHIPSELECT_AMC7823),
        external_clock          => s_registers(FLAGS_IN_0)(FLAGS_IN_0_EXTERNAL_CLOCK),
        adc_delay_update_i      => s_adc_delay_update,
        adc_str_cntvaluein_i    => s_registers(ADC_DELAY)(4 downto 0),
        adc_cha_cntvaluein_i    => s_registers(ADC_DELAY)(12 downto 8),
        adc_chb_cntvaluein_i    => s_registers(ADC_DELAY)(20 downto 16),
        adc_str_cntvalueout_o   => open,

        adc_dout_o              => s_adc_dout,
        clk_adc_o               => s_clk_adc
    );

	cmp_dma_if : dma_if
	generic map
	(
		C_NBITS_VALID_INPUT             => 32,
		C_NBITS_DATA_INPUT				=> 32
	)
	port map
	(
		-- External Ports. S2MM (streaming to memory mapped)
		dma_clk_i             		 	=> dma_clk,   
		dma_valid_o             		=> dma_valid, 
		dma_data_o              		=> dma_data,  
		dma_be_o                		=> dma_be,    
		dma_last_o              		=> dma_last,  
		dma_ready_i             		=> dma_ready, 
		
		-- From data_i generator: simple counter for now!
		data_clk_i		               	=> s_clk_adc,
		data_i       	          	  	=> s_adc_dout,
		data_valid_i					=> s_dma_if_valid_in,
		-- Nothing (?) can be done here as the data from ADC would be lost anyway
		data_ready_o					=> open,
		
		-- Capture control
		capture_ctl_i				   	=> s_registers(SAMPLES_REG),
		-- Signals syncronized with data_clk_i. Need synchronization with
		-- Bus clock domain
		dma_complete_o					=> s_dma_complete,
		dma_ovf_o						=> s_dma_ovf,
				
		-- Reset signal
		rst_i						   	=> rst,
		
		-- Debug Signals
		dma_debug_clk_o            		=> debug_clk,    
		dma_debug_data_o           		=> debug_data,   
		dma_debug_trigger_o        		=> debug_trigger
	);
	
	s_dma_if_valid_in 					<= '1';
	
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
  
end rtl;