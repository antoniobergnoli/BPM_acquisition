library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package utilities_pkg is
	component fifo is
	port (
		rst 			: in std_logic;
		wr_clk 			: in std_logic;
		rd_clk 			: in std_logic;
		din 			: in std_logic_vector(32 downto 0);
		wr_en 			: in std_logic;
		rd_en 			: in std_logic;
		dout 			: out std_logic_vector(32 downto 0);
		full 			: out std_logic;
		empty 			: out std_logic;
		rd_data_count 	: out std_logic_vector ( 12 downto 0 ); 
		wr_data_count 	: out std_logic_vector ( 12 downto 0 ) 
	);
	end component fifo;
	
end utilities_pkg;