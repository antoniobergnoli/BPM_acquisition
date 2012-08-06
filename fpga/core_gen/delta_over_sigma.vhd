library ieee;
use ieee.std_logic_1164.all;

----------------------------------------------------------------------------------------------
-- delta_over_sigma
----------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.arith_dsp48e_pkg.all;
use work.utilities_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity delta_over_sigma is
generic
(
	-- Fixed in 24!
	G_DATAIN_WIDTH    : integer := 24
);
port
(
    i_clk         : in  std_logic;
    i_rst         : in  std_logic;
    i_a           : in  std_logic_vector(G_DATAIN_WIDTH-1 downto 0);
    i_b           : in  std_logic_vector(G_DATAIN_WIDTH-1 downto 0);
    i_c           : in  std_logic_vector(G_DATAIN_WIDTH-1 downto 0);
    i_d           : in  std_logic_vector(G_DATAIN_WIDTH-1 downto 0);
    o_x           : out std_logic_vector(G_DATAIN_WIDTH+1 downto 0);
    o_y           : out std_logic_vector(G_DATAIN_WIDTH+1 downto 0);
    o_z           : out std_logic_vector(G_DATAIN_WIDTH+1 downto 0);
    o_sum         : out std_logic_vector(G_DATAIN_WIDTH+1 downto 0);
    i_valid       : in  std_logic;
    o_rdy         : out std_logic;
	
	o_valid		  : out std_logic;
	i_rdy		  : in std_logic;
	
    o_err         : out std_logic
);
end delta_over_sigma;

architecture rtl of delta_over_sigma is

	signal o_x_32					: std_logic_vector(31 downto 0);
	signal o_y_32					: std_logic_vector(31 downto 0);
	signal o_z_32					: std_logic_vector(31 downto 0);

    signal sl_reg0_valid   			: std_logic := '0';
    signal sl_reg1_valid   			: std_logic := '0';

    signal sv_a_plus_b     			: signed(G_DATAIN_WIDTH downto 0) := (others => '0');
    signal sv_c_plus_d     			: signed(G_DATAIN_WIDTH downto 0) := (others => '0');
    signal sv_a_plus_d     			: signed(G_DATAIN_WIDTH downto 0) := (others => '0');
    signal sv_b_plus_c     			: signed(G_DATAIN_WIDTH downto 0) := (others => '0');
    signal sv_a_plus_c     			: signed(G_DATAIN_WIDTH downto 0) := (others => '0');
    signal sv_b_plus_d     			: signed(G_DATAIN_WIDTH downto 0) := (others => '0');
			
    signal sv_delta_x      			: signed(G_DATAIN_WIDTH+1 downto 0) := (others => '0');
	signal sv_delta_x_32			: std_logic_vector(31 downto 0);
    signal sv_delta_y      			: signed(G_DATAIN_WIDTH+1 downto 0) := (others => '0');
	signal sv_delta_y_32			: std_logic_vector(31 downto 0);
    signal sv_delta_z      			: signed(G_DATAIN_WIDTH+1 downto 0) := (others => '0');
	signal sv_delta_z_32			: std_logic_vector(31 downto 0);
    signal sv_sum          			: signed(G_DATAIN_WIDTH+1 downto 0) := (others => '0');
	signal sv_sum_32				: std_logic_vector(31 downto 0);
	
	-- Divider Signals
	signal dividend_x_ready			: std_logic;
	signal divisor_x_ready			: std_logic;
	signal dividend_y_ready			: std_logic;
	signal divisor_y_ready			: std_logic;
	signal dividend_z_ready			: std_logic;
	signal divisor_z_ready			: std_logic;
	
	signal divider_x_valid			: std_logic;
	signal divider_y_valid			: std_logic;
	signal divider_z_valid			: std_logic;
    
begin
	-- aclk : in STD_LOGIC := 'X'; 
    -- s_axis_divisor_tvalid : in STD_LOGIC := 'X'; 
    -- s_axis_dividend_tvalid : in STD_LOGIC := 'X'; 
    -- m_axis_dout_tready : in STD_LOGIC := 'X'; 
    -- s_axis_divisor_tready : out STD_LOGIC; 
    -- s_axis_dividend_tready : out STD_LOGIC; 
    -- m_axis_dout_tvalid : out STD_LOGIC; 
    -- s_axis_divisor_tdata : in STD_LOGIC_VECTOR ( 25 downto 0 ); 
    -- s_axis_dividend_tdata : in STD_LOGIC_VECTOR ( 25 downto 0 ); 
    -- m_axis_dout_tdata : out STD_LOGIC_VECTOR ( 25 downto 0 ) 

	o_rdy <= '1' when dividend_x_ready = '1' and divisor_x_ready = '1' and
				dividend_y_ready = '1' and divisor_y_ready = '1' and
				dividend_z_ready = '1' and divisor_z_ready = '1' else '0';
				
	o_valid	<= '1' when divider_x_valid = '1' and divider_y_valid = '1' and
				divider_z_valid = '1' else '0';
				
	sv_sum_32(31 downto 26) 	<= (others => '0');
	sv_sum_32(25 downto 0) 		<= std_logic_vector(sv_sum);			

   fixed_point_divider_inst_x: fixed_point_divider
    port map
    (
        aclk 						=> i_clk,
		
        s_axis_dividend_tdata 		=> sv_delta_x_32,
		s_axis_dividend_tvalid		=> sl_reg1_valid,
		s_axis_dividend_tready		=> dividend_x_ready,
		
        s_axis_divisor_tdata 		=> sv_sum_32,
		s_axis_divisor_tvalid		=> sl_reg1_valid,
		s_axis_divisor_tready		=> divisor_x_ready,
		
        m_axis_dout_tdata 			=> o_x_32,
		m_axis_dout_tvalid			=> divider_x_valid,

        m_axis_dout_tready 			=> i_rdy
    );
	
	sv_delta_x_32(31 downto 26) 	<= (others => '0');
	sv_delta_x_32(25 downto 0) 		<= std_logic_vector(sv_delta_x);
	o_x								<= o_x_32(25 downto 0);
    
    fixed_point_divider_inst_y: fixed_point_divider
     port map
    (
        aclk 						=> i_clk,
		
        s_axis_dividend_tdata 		=> sv_delta_y_32,
		s_axis_dividend_tvalid		=> sl_reg1_valid,
		s_axis_dividend_tready		=> dividend_y_ready,
		
        s_axis_divisor_tdata 		=> sv_sum_32,
		s_axis_divisor_tvalid		=> sl_reg1_valid,
		s_axis_divisor_tready		=> divisor_y_ready,
		
        m_axis_dout_tdata 			=> o_y_32,
		m_axis_dout_tvalid			=> divider_y_valid,

        m_axis_dout_tready 			=> i_rdy
    );
	
	sv_delta_y_32(31 downto 26) 	<= (others => '0');
	sv_delta_y_32(25 downto 0) 		<= std_logic_vector(sv_delta_y);
	o_y								<= o_y_32(25 downto 0);
    
    fixed_point_divider_inst_z: fixed_point_divider
     port map
    (
        aclk 						=> i_clk,
		
        s_axis_dividend_tdata 		=> sv_delta_z_32,
		s_axis_dividend_tvalid		=> sl_reg1_valid,
		s_axis_dividend_tready		=> dividend_z_ready,
		
        s_axis_divisor_tdata 		=> sv_sum_32,
		s_axis_divisor_tvalid		=> sl_reg1_valid,
		s_axis_divisor_tready		=> divisor_z_ready,
		
        m_axis_dout_tdata 			=> o_z_32,
		m_axis_dout_tvalid			=> divider_z_valid,

        m_axis_dout_tready 			=> i_rdy
    );
	
	sv_delta_z_32(31 downto 26) 	<= (others => '0');
	sv_delta_z_32(25 downto 0) 		<= std_logic_vector(sv_delta_z);
	o_z								<= o_z_32(25 downto 0);
    
    prc_sum_divide: process(i_rst, i_clk)
        variable v_sv_a: signed(G_DATAIN_WIDTH downto 0);
        variable v_sv_b: signed(G_DATAIN_WIDTH downto 0);
        variable v_sv_c: signed(G_DATAIN_WIDTH downto 0);
        variable v_sv_d: signed(G_DATAIN_WIDTH downto 0);

        variable v_sv_a_plus_d  : signed(G_DATAIN_WIDTH+1 downto 0);
        variable v_sv_b_plus_c  : signed(G_DATAIN_WIDTH+1 downto 0);
        variable v_sv_a_plus_b  : signed(G_DATAIN_WIDTH+1 downto 0);
        variable v_sv_c_plus_d  : signed(G_DATAIN_WIDTH+1 downto 0);
        variable v_sv_a_plus_c  : signed(G_DATAIN_WIDTH+1 downto 0);
        variable v_sv_b_plus_d  : signed(G_DATAIN_WIDTH+1 downto 0);
    
    begin
        if i_rst = '1' then
            sl_reg0_valid	<= '0';
			sl_reg1_valid	<= '0';			

            sv_a_plus_b <= (others=>'0');
            sv_c_plus_d <= (others=>'0'); 
            sv_a_plus_d <= (others=>'0');
            sv_b_plus_c <= (others=>'0');
            sv_a_plus_c <= (others=>'0');
            sv_b_plus_d <= (others=>'0');
                       
        elsif rising_edge(i_clk) then
			-- 2 clock cycle delay for diveder operands, because the sum happens in two clock cycles
			sl_reg0_valid	<= i_valid;	
            sl_reg1_valid   <= sl_reg0_valid;	
			
            v_sv_a_plus_d := resize(sv_a_plus_d, G_DATAIN_WIDTH+2);
            v_sv_b_plus_c := resize(sv_b_plus_c, G_DATAIN_WIDTH+2);
            v_sv_a_plus_b := resize(sv_a_plus_b, G_DATAIN_WIDTH+2);
            v_sv_c_plus_d := resize(sv_c_plus_d, G_DATAIN_WIDTH+2);
            v_sv_a_plus_c := resize(sv_a_plus_c, G_DATAIN_WIDTH+2);
            v_sv_b_plus_d := resize(sv_b_plus_d, G_DATAIN_WIDTH+2);
            
            sv_delta_x <= v_sv_a_plus_d - v_sv_b_plus_c;
            sv_delta_y <= v_sv_a_plus_b - v_sv_c_plus_d;
            sv_delta_z <= v_sv_a_plus_c - v_sv_b_plus_d;
            sv_sum <= v_sv_a_plus_b + v_sv_c_plus_d;
            
            v_sv_a := resize(signed(i_a), G_DATAIN_WIDTH+1);
            v_sv_b := resize(signed(i_b), G_DATAIN_WIDTH+1);
            v_sv_c := resize(signed(i_c), G_DATAIN_WIDTH+1);
            v_sv_d := resize(signed(i_d), G_DATAIN_WIDTH+1);
            
            if i_valid = '1' then
              sv_a_plus_b <= v_sv_a + v_sv_b;
              sv_c_plus_d <= v_sv_c + v_sv_d;
              sv_a_plus_d <= v_sv_a + v_sv_d;
              sv_b_plus_c <= v_sv_b + v_sv_c;
              sv_a_plus_c <= v_sv_a + v_sv_c;
              sv_b_plus_d <= v_sv_b + v_sv_d;
            end if;
        end if;
    end process;    

    prc_sum: process(i_rst, i_clk)
    begin
        if i_rst = '1' then
            o_sum <= (others=>'0');
        elsif rising_edge(i_clk) then
            if sl_reg0_valid = '1' then
                o_sum <= std_logic_vector(sv_sum);
            end if;
        end if;
    end process;
    
end rtl; 