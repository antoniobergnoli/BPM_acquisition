library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reset_synch is
	port 
	(
		clk_i     		: in  std_logic;
		asyncrst_i		: in  std_logic;
		rst_o      		: out std_logic
	);
end reset_synch;

architecture rtl of reset_synch is
	signal rff1 		: std_logic;
begin
	process(clk_i, asyncrst_i)
	begin
		if asyncrst_i = '1' then
		  rff1  			<= '1';
		  rst_o 			<= '1';
		elsif rising_edge(clk_i) then
		  rff1  			<= '0';
		  rst_o 			<= rff1;
		end if;
	end process;
end rtl;