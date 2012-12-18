------------------------------------------------------------------------------
-- dma_if.vhd - entity/architecture pair
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- FIFO
--Library UNISIM;
--use UNISIM.vcomponents.all;
LIBRARY XilinxCoreLib;

library work;
use work.dma_pkg.all;
use work.utilities_pkg.all;

------------------------------------------------------------------------------
-- Entity section
------------------------------------------------------------------------------

entity dma_if is
	generic
	(
		-- Three 32-bit data input. LSB bits are valid.
	    C_NBITS_VALID_INPUT             	: natural := 128;
		C_NBITS_DATA_INPUT					: natural := 128;
		C_OVF_COUNTER_SIZE					: natural := 10
	);
	port
	(
		-- External Ports. S2MM (streaming to memory mapped)
		dma_clk_i             		   		: in  std_logic;
		dma_valid_o             		   	: out std_logic;
		dma_data_o              		   	: out std_logic_vector(C_NBITS_DATA_INPUT-1 downto 0);
		dma_be_o                		   	: out std_logic_vector(C_NBITS_DATA_INPUT/8 - 1 downto 0);
		dma_last_o              		   	: out std_logic;
		dma_ready_i             		   	: in  std_logic;
		
		-- From ADC
		data_clk_i		               		: in std_logic;
		data_i       	          	  		: in std_logic_vector(C_NBITS_DATA_INPUT-1 downto 0);
		data_valid_i						: in std_logic;
		data_ready_o						: out std_logic;
		
		-- Capture control
		capture_ctl_i				   		: in std_logic_vector(31 downto 0);
		dma_complete_o						: out std_logic;
		dma_ovf_o							: out std_logic;
		
		-- Reset signal
		rst_i						   		: in std_logic;
		
		-- Debug Signals
		dma_debug_clk_o            		   	: out std_logic;
		dma_debug_data_o           		   	: out std_logic_vector(255 downto 0);
		dma_debug_trigger_o        		   	: out std_logic_vector(15 downto 0)
	);
end entity dma_if;

architecture IMP of dma_if is
	constant C_DATA_SIZE					: natural := 32;
	--constant C_OVF_COUNTER_SIZE			: natural := 10;
	-- FIFO signals index 	
	constant C_X_DATA						: natural := 3;
	constant C_Y_DATA						: natural := 2;
	constant C_Z_DATA						: natural := 1;
	constant C_W_DATA						: natural := 0;
	
	------------------------------------------
	-- FIFO Signals
	------------------------------------------
	type fifo_data is array(0 to (C_NBITS_VALID_INPUT/C_DATA_SIZE)-1) of std_logic_vector(32 downto 0);
	type fifo_count is array(0 to (C_NBITS_VALID_INPUT/C_DATA_SIZE)-1) of std_logic_vector(12 downto 0);
	type fifo_parity is array(0 to (C_NBITS_VALID_INPUT/C_DATA_SIZE)-1) of std_logic_vector(7 downto 0);
	type fifo_ctrl is array(0 to (C_NBITS_VALID_INPUT/C_DATA_SIZE)-1) of std_logic;
	
	signal fifo_do_concat					: std_logic_vector(C_NBITS_VALID_INPUT-1 downto 0);
	signal data_i_d1						: std_logic_vector(C_NBITS_DATA_INPUT-1 downto 0);

	-- read data_i: 64-bit (each) output: read output data_i
	signal fifo_do 							: fifo_data;
	-- status: 1-bit (each) output: flags and other fifo status outputs
	signal fifo_empty						: fifo_ctrl; 
	signal fifo_full						: fifo_ctrl;
	-- read control signals: 1-bit (each) input: read clock, enable and reset input signals
	signal fifo_rdclk    					: fifo_ctrl;	         
	signal fifo_rden                    	: fifo_ctrl;
	signal fifo_rst                    		: fifo_ctrl;
	-- counter fifo signals
	signal fifo_rd_data_count				: fifo_count;
	signal fifo_wr_data_count				: fifo_count;
	-- write control signals: 1-bit (each) input: write clock and enable input signals
	signal fifo_wrclk   					: fifo_ctrl;             		
	signal fifo_wren                      	: fifo_ctrl;
	-- write data_i: 64-bit (each) input: write input data_i
	signal fifo_di							: fifo_data;                  
	signal last_data_reg					: std_logic;
	-- Overflow counter. One extra bit for overflow easy overflow detection
	signal s_fifo_ovf_c						: std_logic_vector(C_OVF_COUNTER_SIZE downto 0);
	signal s_fifo_ovf						: std_logic;
  
  ------------------------------------------
  -- Internal Control
  ------------------------------------------
	signal capture_ctl_reg					: std_logic_vector(21 downto 0);
	signal start_acq						: std_logic;
	signal start_acq_reg0   				: std_logic;   
	signal start_acq_reg1   				: std_logic; 
	signal start_acq_reg2   				: std_logic; 
	signal start_acq_trig					: std_logic; 
  
  ------------------------------------------
  -- Reset Synch
  ------------------------------------------
	signal data_rst_reg0					: std_logic;
	signal data_rst_reg1               		: std_logic;
	signal data_clk_rst           			: std_logic;
	
	signal dma_rst_reg0						: std_logic;
	signal dma_rst_reg1                 	: std_logic;
	signal dma_clk_rst						: std_logic;
  
  ------------------------------------------
  -- DMA output signals
  ------------------------------------------
	-- C_NBITS_DATA_INPUT+1 bits. C_NBITS_DATA_INPUT bits (LSBs) for data_i and 1 bit (MSB) for last data_i bit
	signal dma_data_out0					: std_logic_vector(C_NBITS_DATA_INPUT downto 0);
	signal dma_valid_out0					: std_logic;
	
	signal dma_data_out1					: std_logic_vector(C_NBITS_DATA_INPUT downto 0);
	signal dma_valid_out1					: std_logic;
	
	signal dma_data_out2					: std_logic_vector(C_NBITS_DATA_INPUT downto 0);
	signal dma_valid_out2					: std_logic;
	
	signal dma_data_out3					: std_logic_vector(C_NBITS_DATA_INPUT downto 0);
	signal dma_valid_out3					: std_logic;
		
	signal dma_valid_s						: std_logic;
	signal dma_ready_s						: std_logic;
	signal dma_last_s						: std_logic;
	signal s_last_data						: std_logic;
	signal dma_valid_reg0					: std_logic;
	--signal dma_valid_reg1					: std_logic;
   
	-- Counter to coordinate the FIFO output - DMA input
	signal output_counter_rd				: std_logic_vector(1 downto 0);
	signal pre_output_counter_wr			: std_logic_vector(1 downto 0);
	
	-- Glue signals
	signal s_dma_complete					: std_logic;
	signal s_dma_last_glue					: std_logic;
	signal s_dma_valid_glue					: std_logic;
	signal s_dma_data_glue					: std_logic_vector(C_NBITS_DATA_INPUT-1 downto 0);
  begin
  
	-- DMA signals glue
	dma_last_o								<= s_dma_last_glue;
	dma_valid_o								<= s_dma_valid_glue;	
	dma_data_o								<= s_dma_data_glue;
	
	-- Debug data_i
	dma_debug_clk_o    						<= dma_clk_i;
	
	dma_debug_trigger_o(15 downto 6)   		<= (others => '0');
	dma_debug_trigger_o(5)					<= fifo_full(C_W_DATA);
	dma_debug_trigger_o(4)					<= start_acq_trig;
	dma_debug_trigger_o(3)					<= capture_ctl_reg(21);
	dma_debug_trigger_o(2)   				<= dma_ready_i;
	dma_debug_trigger_o(1)   				<= s_dma_last_glue;
	dma_debug_trigger_o(0)   				<= s_dma_valid_glue;
	
	dma_debug_data_o(255 downto 120) 		<= (others => '0');
	dma_debug_data_o(119 downto 109)		<= s_fifo_ovf_c(10 downto 0);
	dma_debug_data_o(108)					<= s_dma_complete;
	dma_debug_data_o(107)					<= start_acq_trig;
	dma_debug_data_o(106)					<= fifo_full(C_W_DATA);
	dma_debug_data_o(105 downto 84)			<= capture_ctl_reg;
	dma_debug_data_o(83 downto 52) 			<= s_dma_data_glue(31 downto 0);	
	dma_debug_data_o(51 downto 36) 			<= fifo_do(C_W_DATA)(15 downto 0);-- FIXXXX
	dma_debug_data_o(35 downto 34) 			<= output_counter_rd;
	dma_debug_data_o(33 downto 32) 			<= pre_output_counter_wr;
	dma_debug_data_o(31 downto 19) 			<= fifo_wr_data_count(C_W_DATA);--(5 downto 0);
	dma_debug_data_o(18 downto  6) 			<= fifo_rd_data_count(C_W_DATA);--(5 downto 0);
	dma_debug_data_o(5) 					<= dma_ready_s;
	dma_debug_data_o(4) 					<= dma_valid_reg0;
	dma_debug_data_o(3) 					<= dma_valid_s;
	dma_debug_data_o(2) 					<= dma_ready_i;
	dma_debug_data_o(1) 					<= s_dma_last_glue;
	dma_debug_data_o(0) 					<= s_dma_valid_glue;
	
	--------------------------------
	-- Reset Logic		
	--------------------------------
	-- FIFO reset cycle:  RST must be held high for at least three RDCLK clock cycles,
	--	and RDEN must be low for four clock cycles before RST becomes active high, and RDEN 
	-- remains low during this reset cycle.
	-- Is this really necessary? REVIEW!
	
	-- Guarantees the synchronicity with the input clock on reset deassertion
	cmp_reset_synch_dma : reset_synch
	port map
	(
		clk_i     		=> dma_clk_i,
		asyncrst_i		=> rst_i,
		rst_o      		=> dma_clk_rst
	);
	
	cmp_reset_synch_data : reset_synch
	port map
	(
		clk_i     		=> data_clk_i,
		asyncrst_i		=> rst_i,
		rst_o      		=> data_clk_rst
	);
	
	--------------------------------
	-- Start Acquisition logic		
	--------------------------------
	-- Simple trigger detector 0 -> 1 for start_acq.
	-- Synchronize with bus clock data_clk_i might not be the same
   p_start_acq_trig : process (data_clk_i)
   begin
	if rising_edge(data_clk_i) then
		if data_clk_rst = '1' then
			start_acq_reg0 <= '0';
			start_acq_reg1 <= '0';
			start_acq_reg2 <= '0';
			start_acq_trig <= '0';
		else
			-- More flip flop levels than necessary because bus_clk and data_clk_i might be different!
			start_acq_reg0 <= start_acq;
			start_acq_reg1 <= start_acq_reg0;
			start_acq_reg2 <= start_acq_reg1;
			start_acq_trig <= (not start_acq_reg2) and start_acq_reg1;
			--start_acq_trig <= start_acq_reg2 xor start_acq_reg1;
		end if;
	end if;
   end process p_start_acq_trig;

   -- Bit representing the start acquisition signal
	start_acq							<= capture_ctl_i(21);
	
	--------------------------------
	-- Samples Counter Logic		
	--------------------------------
	-- Hold counter for "capture_count" clock cycles
	p_samples_counter : process (data_clk_i)
	begin
	if rising_edge(data_clk_i) then
		if data_clk_rst = '1' then
			capture_ctl_reg <= (others => '0');
		elsif capture_ctl_reg(21) = '1' and data_valid_i = '1' and fifo_full(C_W_DATA) = '0' then		-- start counting and stop only when we have input all data to fifos
			capture_ctl_reg <= std_logic_vector(unsigned(capture_ctl_reg) - 1);
		elsif start_acq_trig = '1' then				-- assign only when 0 -> 1 transition of MSB of start_acq. MSB of capture_ctl_reg
			if data_valid_i = '1' then
				capture_ctl_reg <= '1' & std_logic_vector(unsigned(capture_ctl_i(20 downto 0)) - 1);	-- MSB of capture_ctl_i might not be 1 by this time. Force to 1 then...
			else		-- Do not decrement now. wait until data_valid is set
				capture_ctl_reg <= '1' & std_logic_vector(unsigned(capture_ctl_i(20 downto 0)));
			end if;
		end if;
	end if;
	end process p_samples_counter;
	
	--------------------------------
	-- DMA Last Data Logic		
	--------------------------------
   
	p_last_data_proc : process(data_clk_i)
	begin
		if rising_edge(data_clk_i) then
			if data_clk_rst = '1' then
				last_data_reg <= '0';
			--elsif s_last_data = '1' then
			--	last_data_reg <= data_valid_i;
			--else 
			--	last_data_reg <= '0';
			else
				last_data_reg <= s_last_data;
			end if;
		end if;
	end process p_last_data_proc;
	
	-- bit 21 = 1 and bits 20 downto 0 = 0
	s_last_data								<= '1' when capture_ctl_reg(21 downto 0) = "1000000000000000000000" and data_valid_i = '1' else '0';
	
	--------------------------------
	-- FIFO Write Enable Logic		
	--------------------------------
	
	gen_fifo_wren_inst : for i in 0 to (C_NBITS_VALID_INPUT/C_DATA_SIZE)-1 generate
	p_fifo_wr_en : process(data_clk_i)
	begin
	if rising_edge(data_clk_i) then
		if data_clk_rst = '1' then
			--last_data_s <= '0';
			--gen_fifo_signals_inst : for i in 0 to (C_NBITS_VALID_INPUT/C_DATA_SIZE)-1 generate
				fifo_wren(i) <= '0';
			--end generate;
		-- We only need to consider one as all FIFOs are synchronized with each other
		elsif fifo_full(C_W_DATA) = '0' then
			-- input data to fifo only when data is valid
			fifo_wren(i) <= capture_ctl_reg(21) and data_valid_i;
		end if;
		
		--Necessary in order to input data to FIFO correctly as fifo_wren is registered
		data_i_d1 <= data_i;
		
	end if;
	end process p_fifo_wr_en;
	end generate;
	
	--------------------------------
	-- DMA Output Logic		
	--------------------------------
	dma_ready_s <= dma_ready_i or not s_dma_valid_glue;
	-- fifo is not empty and dma is ready
	dma_valid_s <= '0' when fifo_empty(C_W_DATA) = '1' else dma_ready_i;
	
	-- FIFO concatenation
	gen_fifo_do_concat_inst : for i in 0 to (C_NBITS_VALID_INPUT/C_DATA_SIZE)-1 generate
		fifo_do_concat(C_DATA_SIZE*(i+1)-1 downto C_DATA_SIZE*i)	<=	fifo_do(i)(C_DATA_SIZE-1 downto 0);
	end generate;
	
	-- We have a 2 output delay for FIFO. That being said, if we have a dma_ready_i signal it will take 2 dma clock cycles
	-- in order to read the data_i from FIFO.
	-- By this time, dma_ready_i might not be set and we have to wait for it. To solve this 2 delay read cycle
	-- it is employed a small 4 position "buffer" to hold the values read from fifo but not yet passed to the DMA.
	-- Note that dma_valid_reg0 is 1 clock cycle delayed in relation to dma_valid_s. That should give time to
	-- FIFO output the data_i requested. Also not that that difference between pre_output_counter_wr and output_counter_rd
	-- is at most (at any given point in time) not greater than 2. Thus, with a 2 bit counter, we will not have overflow
	p_dma_pre_output : process(dma_clk_i)
	begin
	if rising_edge(dma_clk_i) then
		if dma_clk_rst = '1' then
			dma_data_out0 <= (others => '0');
			dma_valid_out0 <= '0';	
			dma_data_out1 <= (others => '0');
			dma_valid_out1 <= '0';	
			dma_data_out2 <= (others => '0');
			dma_valid_out2 <= '0';	
			dma_data_out3 <= (others => '0');
			dma_valid_out3 <= '0';	
			
			dma_valid_reg0 <= '0';
			--dma_valid_reg1 <= '0';
			pre_output_counter_wr <= (others => '0');		
		-- fifo is not empty and dma is ready
		else--if dma_valid_reg1 = '1' then -- fifo output should be valid by now as fifo_rden was enabled and it id not empty!
			-- Store output from FIFO in the correct dma_data_outX if dma_valid_reg1 is valid.
			-- On the next dma_valid_reg1 operation (next clock cycle if dma_valid_reg1 remains 1),
			-- clear the past dma_data_outX if dma has read from it (read pointer is in the past write position).
			if  pre_output_counter_wr = "00" and dma_valid_reg0 = '1' then
				-- Output only the last_data bit of C_X_DATA as all the others are equal
				dma_data_out0(C_NBITS_DATA_INPUT) <= fifo_do(C_W_DATA)(C_DATA_SIZE);
				-- Output the data from fifo itself
				dma_data_out0(C_NBITS_DATA_INPUT-1 downto 0) <= std_logic_vector(RESIZE(unsigned(fifo_do_concat), C_NBITS_DATA_INPUT));
				dma_valid_out0 <= '1';
			elsif output_counter_rd = "00" and dma_ready_s = '1' then
				dma_data_out0 <= (others => '0');
				dma_valid_out0 <= '0';
			end if;
			
			if  pre_output_counter_wr = "01" and dma_valid_reg0 = '1' then --dma_valid_reg1 = '1' then
				dma_data_out1(C_NBITS_DATA_INPUT) <= fifo_do(C_W_DATA)(C_DATA_SIZE);
				dma_data_out1(C_NBITS_DATA_INPUT-1 downto 0) <= std_logic_vector(RESIZE(unsigned(fifo_do_concat), C_NBITS_DATA_INPUT));
				dma_valid_out1 <= '1';
			elsif output_counter_rd = "01" and dma_ready_s = '1' then
				dma_data_out1 <= (others => '0');
				dma_valid_out1 <= '0';
			end if;
			
			if  pre_output_counter_wr = "10" and dma_valid_reg0 = '1' then
				dma_data_out2(C_NBITS_DATA_INPUT) <= fifo_do(C_W_DATA)(C_DATA_SIZE);
				dma_data_out2(C_NBITS_DATA_INPUT-1 downto 0) <= std_logic_vector(RESIZE(unsigned(fifo_do_concat), C_NBITS_DATA_INPUT));
				dma_valid_out2 <= '1';
			elsif output_counter_rd = "10" and dma_ready_s = '1' then
				dma_data_out2 <= (others => '0');
				dma_valid_out2 <= '0';
			end if;
			
			if  pre_output_counter_wr = "11" and dma_valid_reg0 = '1' then
				dma_data_out3(C_NBITS_DATA_INPUT) <= fifo_do(C_W_DATA)(C_DATA_SIZE);
				dma_data_out3(C_NBITS_DATA_INPUT-1 downto 0) <= std_logic_vector(RESIZE(unsigned(fifo_do_concat), C_NBITS_DATA_INPUT));
				dma_valid_out3 <= '1';
			elsif output_counter_rd = "11" and dma_ready_s = '1' then
				dma_data_out3 <= (others => '0');
				dma_valid_out3 <= '0';
			end if;
			
			if dma_valid_reg0 = '1' then --dma_valid_reg0 = '1' then
				pre_output_counter_wr <= std_logic_vector(unsigned(pre_output_counter_wr) + 1);	
			end if;
		
		-- 2 clock cycle delay for read from fifo.
		-- Nedded to break logic into one more FF as timing constraint wasn't met,
		-- due to the use of dma_valid_s directly into fifo_rden.
		-- This is not a problem since there is a 4 position "buffer" after this
		-- to absorb dma_ready_i deassertion
		dma_valid_reg0 <= dma_valid_s;
		--dma_valid_reg0 <= dma_valid_s;
		--dma_valid_reg1 <= dma_valid_reg0;
		end if;
	end if;
	end process p_dma_pre_output;
	
	-- Send to DMA the correct data_i from dma_data_outW, based on the currently read pointer position
	p_dma_output_proc : process(dma_clk_i)
	begin
	if rising_edge(dma_clk_i) then
		if dma_clk_rst = '1' then		
			s_dma_data_glue <= (others => '0');
			s_dma_valid_glue <= '0';
			dma_be_o <= (others => '0');	
			-- The MSB is an indicator of the last data_i requested!
			s_dma_last_glue <= '0';
			output_counter_rd <= (others => '0');
		elsif dma_ready_s = '1' then
			-- verify wr counter and output corresponding output
			case output_counter_rd is
				when "11" =>
					s_dma_data_glue <= dma_data_out3(C_NBITS_DATA_INPUT-1 downto 0);
					s_dma_valid_glue <= dma_valid_out3;
					dma_be_o <= (others => '1');
					-- The MSB is an indicator of the last data_i requested!
					s_dma_last_glue <= dma_data_out3(C_NBITS_DATA_INPUT) and dma_valid_out3;	-- Error ?? CHECK!!!1
				when "10" =>
					s_dma_data_glue <= dma_data_out2(C_NBITS_DATA_INPUT-1 downto 0);
					s_dma_valid_glue <= dma_valid_out2;
					dma_be_o <= (others => '1');
					-- The MSB is an indicator of the last data_i requested!
					s_dma_last_glue <= dma_data_out2(C_NBITS_DATA_INPUT) and dma_valid_out2;
				when "01" =>
					s_dma_data_glue <= dma_data_out1(C_NBITS_DATA_INPUT-1 downto 0);
					s_dma_valid_glue <= dma_valid_out1;
					dma_be_o <= (others => '1');
					-- The MSB is an indicator of the last data_i requested!
					s_dma_last_glue <= dma_data_out1(C_NBITS_DATA_INPUT) and dma_valid_out1;
				--when "01" =>
				when others => 
					s_dma_data_glue <= dma_data_out0(C_NBITS_DATA_INPUT-1 downto 0);
					s_dma_valid_glue <= dma_valid_out0;
					dma_be_o <= (others => '1');
					-- The MSB is an indicator of the last data_i requested!
					s_dma_last_glue <= dma_data_out0(C_NBITS_DATA_INPUT) and dma_valid_out0;	
			end case;
			
			-- Only increment output_counter_rd if it is different from pre_output_counter_wr
			-- to prevent overflow!
			if output_counter_rd /= pre_output_counter_wr then
				output_counter_rd <= std_logic_vector(unsigned(output_counter_rd) + 1);
			end if;
		end if;	
	end if;
	end process p_dma_output_proc;
	
	-- Simple backpressure scheme. Should be almost full for correct behavior.
	-- fifo_full is already synchronized with fifo write_clock
	data_ready_o							<= not fifo_full(C_W_DATA);
	
	--------------------------------
	-- DMA complete status		
	--------------------------------
	dma_last_s 								<= s_dma_valid_glue and dma_ready_i and s_dma_last_glue;

	p_dma_complete : process (dma_clk_i)
	begin
	if rising_edge(dma_clk_i) then
		if dma_clk_rst = '1' then	
			s_dma_complete <= '0';
		elsif dma_last_s = '1' then
			-- DMA could be held to 1 when completed, but it would be more difficult
			-- to bring it back to 0, since the dma transfer is initiated in the data_clk_i domain
			s_dma_complete <= not s_dma_complete;
		end if;
	end if;
	end process p_dma_complete;
	
	dma_complete_o							<= s_dma_complete;
	
	--------------------------------
	-- DMA overflow (fifo full) status and counter	
	--------------------------------
	
	-- Data is lost when this is asserted.
	-- FIFO is full, there is data valid on input and we are in the middle of a dma transfer
	s_fifo_ovf								<= fifo_full(C_W_DATA) and data_valid_i and capture_ctl_reg(21);
	
	p_dma_overflow : process (data_clk_i)
	begin
	if rising_edge(data_clk_i) then
		--No need for reset. On configuration it will default to zero!
		if start_acq_trig = '1' then
			s_fifo_ovf_c <= (others => '0');
		elsif s_fifo_ovf = '1' then
			-- Even if the counter wrapps around, an overflow would still be detected!
			s_fifo_ovf_c <= '1' & std_logic_vector(unsigned(s_fifo_ovf_c(C_OVF_COUNTER_SIZE-1 downto 0)) + 1);
		end if;
	end if;
	end process p_dma_overflow;
	
	dma_ovf_o								<= s_fifo_ovf_c(C_OVF_COUNTER_SIZE);
	
	--------------------------------
	-- FIFO instantiation
	--------------------------------
	-- Indexes
	-- constant C_X_DATA					: natural := 3;
	-- constant C_Y_DATA					: natural := 2;
	-- constant C_Z_DATA					: natural := 1;
	-- constant C_W_DATA					: natural := 0;

	gen_fifo_inst : for i in 0 to (C_NBITS_VALID_INPUT/C_DATA_SIZE)-1 generate
		-- (Built-in FIFO36 primitive)FIFO generated from core generator.
		cmp_fifo : fifo 
		port map(
			rst 								=>	fifo_rst(i),
			wr_clk 								=>	fifo_wrclk(i),
			rd_clk 								=>	fifo_rdclk(i),
			din 								=>	fifo_di(i),	
			wr_en 								=>	fifo_wren(i),
			rd_en 								=>	fifo_rden(i),
			dout 								=>	fifo_do(i),	
			full 								=>	fifo_full(i),
			empty 								=>	fifo_empty(i),
			rd_data_count						=>	fifo_rd_data_count(i),
			wr_data_count                       =>	fifo_wr_data_count(i)
		);
	end generate;
   
	gen_fifo_signals_inst : for i in 0 to (C_NBITS_VALID_INPUT/C_DATA_SIZE)-1 generate
	   -- Drive signals for FIFO. Do a RESET CYCLE! Watch for constraints
		fifo_rst(i)								<= dma_clk_rst;
		fifo_rden(i)							<= dma_valid_s; 
		fifo_rdclk(i)							<= dma_clk_i;
		-- Observe the FIFO reset cycle! dma_clk_buf is the clock for fifo_rd_en
		fifo_wrclk(i)							<= data_clk_i;
		-- C_DATA_SIZE + 1 bits.
		-- It doesn't matter if the data_i is signed or unsigned since we do not care what the input data is.
		-- The user has to treat this and extend the sign if necessary.
		fifo_di(i)(C_DATA_SIZE downto 0)		<= last_data_reg & data_i_d1(C_DATA_SIZE*(i+1) - 1 downto C_DATA_SIZE*i);
	end generate;

  
end IMP;