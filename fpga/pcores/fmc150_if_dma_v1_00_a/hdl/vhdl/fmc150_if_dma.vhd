library ieee;
use ieee.std_logic_1164.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;
use proc_common_v3_00_a.ipif_pkg.all;

library axi_lite_ipif_v1_01_a;
use axi_lite_ipif_v1_01_a.axi_lite_ipif;

library fmc150_if_dma_v1_00_a;
use fmc150_if_dma_v1_00_a.user_logic;

entity fmc150_if_dma is
generic
(
    C_S_AXI_DATA_WIDTH             : integer              := 32;
    C_S_AXI_ADDR_WIDTH             : integer              := 32;
    C_S_AXI_MIN_SIZE               : std_logic_vector     := X"000001FF";
    C_USE_WSTRB                    : integer              := 0;
    C_DPHASE_TIMEOUT               : integer              := 8;
    C_BASEADDR                     : std_logic_vector     := X"FFFFFFFF";
    C_HIGHADDR                     : std_logic_vector     := X"00000000";
    C_FAMILY                       : string               := "virtex6";
    C_NUM_REG                      : integer              := 1;
    C_NUM_MEM                      : integer              := 1;
    C_SLV_AWIDTH                   : integer              := 32;
    C_SLV_DWIDTH                   : integer              := 32
);
port
(
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
    -- pcore external ports
    -----------------------------
    
    --Clock/Data connection to ADC on FMC150 (ADS62P49)
    adc_clk_ab_p            : in    std_logic;
    adc_clk_ab_n            : in    std_logic;
    adc_cha_p               : in    std_logic_vector(6 downto 0);
    adc_cha_n               : in    std_logic_vector(6 downto 0);
    adc_chb_p               : in    std_logic_vector(6 downto 0);
    adc_chb_n               : in    std_logic_vector(6 downto 0);

    --Clock/Data connection to DAC on FMC150 (DAC3283)
    dac_dclk_p              : out   std_logic;
    dac_dclk_n              : out   std_logic;
    dac_data_p              : out   std_logic_vector(7 downto 0);
    dac_data_n              : out   std_logic_vector(7 downto 0);
    dac_frame_p             : out   std_logic;
    dac_frame_n             : out   std_logic;
    txenable                : out   std_logic;
    
    --Clock/Trigger connection to FMC150
    clk_to_fpga_p           : in    std_logic;
    clk_to_fpga_n           : in    std_logic;
    ext_trigger_p           : in    std_logic;
    ext_trigger_n           : in    std_logic;
    
    -- Control signals from/to FMC150
    --Serial Peripheral Interface (SPI)
    spi_sclk                : out   std_logic; -- Shared SPI clock line
    spi_sdata               : out   std_logic; -- Shared SPI data line
    
    -- ADC specific signals
    adc_n_en                : out   std_logic; -- SPI chip select
    adc_sdo                 : in    std_logic; -- SPI data out
    adc_reset               : out   std_logic; -- SPI reset
    
    -- CDCE specific signals
    cdce_n_en               : out   std_logic; -- SPI chip select
    cdce_sdo                : in    std_logic; -- SPI data out
    cdce_n_reset            : out   std_logic;
    cdce_n_pd               : out   std_logic;
    cdce_ref_en             : out   std_logic;
    cdce_pll_status         : in    std_logic;
    
    -- DAC specific signals
    dac_n_en                : out   std_logic; -- SPI chip select
    dac_sdo                 : in    std_logic; -- SPI data out
    
    -- Monitoring specific signals
    mon_n_en                : out   std_logic; -- SPI chip select
    mon_sdo                 : in    std_logic; -- SPI data out
    mon_n_reset             : out   std_logic;
    mon_n_int               : in    std_logic;
    
    --FMC Present status
    prsnt_m2c_l             : in    std_logic;

    rst                     : in    std_logic;
    clk_100Mhz              : in    std_logic;
    clk_200Mhz              : in    std_logic;
    
    adc_dout_o           	: out 	std_logic_vector(31 downto 0);
    clk_adc_o               : out 	std_logic;
	
	-- Up Status
	up_status				: out std_logic_vector(3 downto 0);
		
	-- Debug Signals (to Chipscope)
	debug_clk           	: out 	std_logic;
    debug_data          	: out 	std_logic_vector(255 downto 0);
    debug_trigger       	: out 	std_logic_vector(15 downto 0);
	
	-- AXI Bus Specific Signals

    S_AXI_ACLK              : in  std_logic;
    S_AXI_ARESETN           : in  std_logic;
    S_AXI_AWADDR            : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_AWVALID           : in  std_logic;
    S_AXI_WDATA             : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_WSTRB             : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    S_AXI_WVALID            : in  std_logic;
    S_AXI_BREADY            : in  std_logic;
    S_AXI_ARADDR            : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_ARVALID           : in  std_logic;
    S_AXI_RREADY            : in  std_logic;
    S_AXI_ARREADY           : out std_logic;
    S_AXI_RDATA             : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_RRESP             : out std_logic_vector(1 downto 0);
    S_AXI_RVALID            : out std_logic;
    S_AXI_WREADY            : out std_logic;
    S_AXI_BRESP             : out std_logic_vector(1 downto 0);
    S_AXI_BVALID            : out std_logic;
    S_AXI_AWREADY           : out std_logic
);

    attribute MAX_FANOUT : string;
    attribute SIGIS : string;
    attribute MAX_FANOUT of S_AXI_ACLK      : signal is "10000";
    attribute MAX_FANOUT of S_AXI_ARESETN   : signal is "10000";
    attribute SIGIS of S_AXI_ACLK           : signal is "Clk";
    attribute SIGIS of S_AXI_ARESETN        : signal is "Rst";

end entity fmc150_if_dma;

------------------------------------------------------------------------------
-- Architecture section
------------------------------------------------------------------------------

architecture structure of fmc150_if_dma is

    constant USER_SLV_DWIDTH                : integer := C_S_AXI_DATA_WIDTH;
    
    constant IPIF_SLV_DWIDTH                : integer := C_S_AXI_DATA_WIDTH;
    
    constant ZERO_ADDR_PAD                  : std_logic_vector(0 to 31) := (others => '0');
    constant USER_SLV_BASEADDR              : std_logic_vector     := C_BASEADDR;
    constant USER_SLV_HIGHADDR              : std_logic_vector     := C_HIGHADDR;
    
    constant IPIF_ARD_ADDR_RANGE_ARRAY      : SLV64_ARRAY_TYPE :=
    (
        ZERO_ADDR_PAD & USER_SLV_BASEADDR,  -- user logic slave space base address
        ZERO_ADDR_PAD & USER_SLV_HIGHADDR   -- user logic slave space high address
    );
    
    constant USER_SLV_NUM_REG               : integer := 10;
    constant USER_NUM_REG                   : integer := USER_SLV_NUM_REG;
    constant TOTAL_IPIF_CE                  : integer := USER_NUM_REG;
    
    constant IPIF_ARD_NUM_CE_ARRAY          : INTEGER_ARRAY_TYPE := 
    (
        0  => (USER_SLV_NUM_REG) -- number of ce for user logic slave space
    );
    
    ------------------------------------------
    -- Index for CS/CE
    ------------------------------------------
    constant USER_SLV_CS_INDEX              : integer := 0;
    constant USER_SLV_CE_INDEX              : integer := calc_start_ce_index(IPIF_ARD_NUM_CE_ARRAY, USER_SLV_CS_INDEX);
    
    constant USER_CE_INDEX                  : integer := USER_SLV_CE_INDEX;
    
    ------------------------------------------
    -- IP Interconnect (IPIC) signal declarations
    ------------------------------------------
    signal ipif_Bus2IP_Clk      : std_logic;
    signal ipif_Bus2IP_Resetn   : std_logic;
    signal ipif_Bus2IP_Addr     : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal ipif_Bus2IP_RNW      : std_logic;
    signal ipif_Bus2IP_BE       : std_logic_vector(IPIF_SLV_DWIDTH/8-1 downto 0);
    signal ipif_Bus2IP_CS       : std_logic_vector((IPIF_ARD_ADDR_RANGE_ARRAY'LENGTH)/2-1 downto 0);
    signal ipif_Bus2IP_RdCE     : std_logic_vector(calc_num_ce(IPIF_ARD_NUM_CE_ARRAY)-1 downto 0);
    signal ipif_Bus2IP_WrCE     : std_logic_vector(calc_num_ce(IPIF_ARD_NUM_CE_ARRAY)-1 downto 0);
    signal ipif_Bus2IP_Data     : std_logic_vector(IPIF_SLV_DWIDTH-1 downto 0);
    signal ipif_IP2Bus_WrAck    : std_logic;
    signal ipif_IP2Bus_RdAck    : std_logic;
    signal ipif_IP2Bus_Error    : std_logic;
    signal ipif_IP2Bus_Data     : std_logic_vector(IPIF_SLV_DWIDTH-1 downto 0);
    signal user_Bus2IP_RdCE     : std_logic_vector(USER_NUM_REG-1 downto 0);
    signal user_Bus2IP_WrCE     : std_logic_vector(USER_NUM_REG-1 downto 0);
    signal user_IP2Bus_Data     : std_logic_vector(USER_SLV_DWIDTH-1 downto 0);
    signal user_IP2Bus_RdAck    : std_logic;
    signal user_IP2Bus_WrAck    : std_logic;
    signal user_IP2Bus_Error    : std_logic;

begin

  ------------------------------------------
  -- instantiate axi_lite_ipif
  ------------------------------------------
    AXI_LITE_IPIF_I : entity axi_lite_ipif_v1_01_a.axi_lite_ipif
    generic map
    (
        C_S_AXI_DATA_WIDTH      => IPIF_SLV_DWIDTH,
        C_S_AXI_ADDR_WIDTH      => C_S_AXI_ADDR_WIDTH,
        C_S_AXI_MIN_SIZE        => C_S_AXI_MIN_SIZE,
        C_USE_WSTRB             => C_USE_WSTRB,
        C_DPHASE_TIMEOUT        => C_DPHASE_TIMEOUT,
        C_ARD_ADDR_RANGE_ARRAY  => IPIF_ARD_ADDR_RANGE_ARRAY,
        C_ARD_NUM_CE_ARRAY      => IPIF_ARD_NUM_CE_ARRAY,
        C_FAMILY                => C_FAMILY
    )
    port map
    (
        S_AXI_ACLK              => S_AXI_ACLK,
        S_AXI_ARESETN           => S_AXI_ARESETN,
        S_AXI_AWADDR            => S_AXI_AWADDR,
        S_AXI_AWVALID           => S_AXI_AWVALID,
        S_AXI_WDATA             => S_AXI_WDATA,
        S_AXI_WSTRB             => S_AXI_WSTRB,
        S_AXI_WVALID            => S_AXI_WVALID,
        S_AXI_BREADY            => S_AXI_BREADY,
        S_AXI_ARADDR            => S_AXI_ARADDR,
        S_AXI_ARVALID           => S_AXI_ARVALID,
        S_AXI_RREADY            => S_AXI_RREADY,
        S_AXI_ARREADY           => S_AXI_ARREADY,
        S_AXI_RDATA             => S_AXI_RDATA,
        S_AXI_RRESP             => S_AXI_RRESP,
        S_AXI_RVALID            => S_AXI_RVALID,
        S_AXI_WREADY            => S_AXI_WREADY,
        S_AXI_BRESP             => S_AXI_BRESP,
        S_AXI_BVALID            => S_AXI_BVALID,
        S_AXI_AWREADY           => S_AXI_AWREADY,
        Bus2IP_Clk              => ipif_Bus2IP_Clk,
        Bus2IP_Resetn           => ipif_Bus2IP_Resetn,
        Bus2IP_Addr             => ipif_Bus2IP_Addr,
        Bus2IP_RNW              => ipif_Bus2IP_RNW,
        Bus2IP_BE               => ipif_Bus2IP_BE,
        Bus2IP_CS               => ipif_Bus2IP_CS,
        Bus2IP_RdCE             => ipif_Bus2IP_RdCE,
        Bus2IP_WrCE             => ipif_Bus2IP_WrCE,
        Bus2IP_Data             => ipif_Bus2IP_Data,
        IP2Bus_WrAck            => ipif_IP2Bus_WrAck,
        IP2Bus_RdAck            => ipif_IP2Bus_RdAck,
        IP2Bus_Error            => ipif_IP2Bus_Error,
        IP2Bus_Data             => ipif_IP2Bus_Data
    );

    ------------------------------------------
    -- instantiate User Logic
    ------------------------------------------
    USER_LOGIC_I : entity fmc150_if_dma_v1_00_a.user_logic
    generic map
    (
      C_NUM_REG                      => USER_NUM_REG,
      C_SLV_DWIDTH                   => USER_SLV_DWIDTH
    )
    port map
    (
		-----------------------------
		-- DMA interface signals
		-----------------------------
		dma_clk          =>  dma_clk,    
		dma_valid        =>  dma_valid,  
		dma_data         =>  dma_data,  
		dma_be           =>  dma_be,    
		dma_last         =>  dma_last,    
		dma_ready        =>  dma_ready,   
        -----------------------------
        -- pcore external ports
        -----------------------------
        adc_clk_ab_p    => adc_clk_ab_p,
        adc_clk_ab_n    => adc_clk_ab_n,
        adc_cha_p       => adc_cha_p,
        adc_cha_n       => adc_cha_n,
        adc_chb_p       => adc_chb_p,
        adc_chb_n       => adc_chb_n,
        dac_dclk_p      => dac_dclk_p,
        dac_dclk_n      => dac_dclk_n,
        dac_data_p      => dac_data_p,
        dac_data_n      => dac_data_n,
        dac_frame_p     => dac_frame_p,
        dac_frame_n     => dac_frame_n,
        txenable        => txenable,
        clk_to_fpga_p   => clk_to_fpga_p,
        clk_to_fpga_n   => clk_to_fpga_n,
        ext_trigger_p   => ext_trigger_p,
        ext_trigger_n   => ext_trigger_n,
        spi_sclk        => spi_sclk,
        spi_sdata       => spi_sdata,
        adc_n_en        => adc_n_en,
        adc_sdo         => adc_sdo,
        adc_reset       => adc_reset,
        cdce_n_en       => cdce_n_en,
        cdce_sdo        => cdce_sdo,
        cdce_n_reset    => cdce_n_reset,
        cdce_n_pd       => cdce_n_pd,
        cdce_ref_en     => cdce_ref_en,
        cdce_pll_status => cdce_pll_status,
        dac_n_en        => dac_n_en,
        dac_sdo         => dac_sdo,
        mon_n_en        => mon_n_en,
        mon_sdo         => mon_sdo,
        mon_n_reset     => mon_n_reset,
        mon_n_int       => mon_n_int,
        prsnt_m2c_l     => prsnt_m2c_l,
        rst             => rst,
        clk_100Mhz      => clk_100Mhz,
        clk_200Mhz      => clk_200Mhz,
        adc_dout_o      => adc_dout_o,
        clk_adc_o       => clk_adc_o,
		up_status		=> up_status,

        Bus2IP_Clk      => ipif_Bus2IP_Clk,
        Bus2IP_Resetn   => ipif_Bus2IP_Resetn,
        Bus2IP_Data     => ipif_Bus2IP_Data,
        Bus2IP_BE       => ipif_Bus2IP_BE,
        Bus2IP_RdCE     => user_Bus2IP_RdCE,
        Bus2IP_WrCE     => user_Bus2IP_WrCE,
        IP2Bus_Data     => user_IP2Bus_Data,
        IP2Bus_RdAck    => user_IP2Bus_RdAck,
        IP2Bus_WrAck    => user_IP2Bus_WrAck,
        IP2Bus_Error    => user_IP2Bus_Error,
		
		-- Debug Signals (to Chipscope)
		debug_clk       => debug_clk,
		debug_data      => debug_data,   
		debug_trigger   => debug_trigger
    );

    ------------------------------------------
    -- connect internal signals
    ------------------------------------------
    ipif_IP2Bus_Data    <= user_IP2Bus_Data;
    ipif_IP2Bus_WrAck   <= user_IP2Bus_WrAck;
    ipif_IP2Bus_RdAck   <= user_IP2Bus_RdAck;
    ipif_IP2Bus_Error   <= user_IP2Bus_Error;
    
    user_Bus2IP_RdCE    <= ipif_Bus2IP_RdCE(USER_NUM_REG-1 downto 0);
    user_Bus2IP_WrCE    <= ipif_Bus2IP_WrCE(USER_NUM_REG-1 downto 0);

end structure;