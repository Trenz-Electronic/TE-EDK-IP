----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    18:05:02 01/18/2010 
-- Design Name: 
-- Module Name:    dma_read_path - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


library xps_npi_dma_v3_00_a;
use xps_npi_dma_v3_00_a.all;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity dma_read_path is
	 Generic( C_NPI_DATA_WIDTH  : integer := 64; --32 or 64 bit NPI bus
				 C_SWAP_OUTPUT : integer := 1 --byte swappping switch
				);
    Port ( rst_global : in  STD_LOGIC;
           NPI_Clk : in  STD_LOGIC;
			  
			  	xfer_read           : in std_logic := '0'; --read flag
			   rd_start_addr 	: in std_logic_vector(31 downto 0) := (others => '0');
				rd_addr_ack    : in std_logic := '0'; --ackonwledge address flag
				rd_block_size  : in std_logic_vector(0 to 3) := "0000";
				read_jump 		: in integer := 0; --gap between consecutive read packets
				rows 				: in integer := 0; --number of rows
				rd_words  		: in integer := 0;
				NPI_RdFIFO_Data      : in std_logic_vector (C_NPI_DATA_WIDTH-1 downto 0) := (others => '0');
				NPI_RdFIFO_RdWdAddr  : in std_logic_vector (3 downto 0);
				NPI_RdFIFO_Empty     : in  std_logic;             
				NPI_RdFIFO_Latency   : in std_logic_vector (1 downto 0); --new
				rd_loop           : in std_logic := '0'; --internal counter loopback
				NPI_RNW              : in std_logic := '0';
				NPI_AddrAck          : in  std_logic;
				use_rd_jump 	: in std_logic := '0'; --flag for using jump (used in transpose)
	 
				rd_xfer_done            : out std_logic := '0'; --done flag
				NPI_RdFIFO_Pop       : out std_logic := '0';           
				
				rd_req_addr    : out std_logic := '0'; --request address flag
				NPI_RDAddr_count           : out std_logic_vector(31 downto 0);

				Output_data		    	    : out std_logic_vector(0 to C_NPI_DATA_WIDTH-1);
				Output_valid  		      : out std_logic := '0';
				Output_ready  		      : in std_logic := '1'; --inhibits read
	
			  	ChipScope        	: out std_logic_vector(63 downto 0) := (others => '0')
			  );
end dma_read_path;

architecture Behavioral of dma_read_path is

	signal rd_block_bytes   : integer range 0 to 256 := 0; --current transfer counter (words)
	signal row_counter : integer := 0; --number of rows
	signal row_counter_r : integer := 0; --number of rows
	signal rd_xfer_done_i  : std_logic := '0'; --done flag
   signal rd_data_cnt 		: integer := 0;
   signal NPI_RDAddr_count_i           : std_logic_vector(31 downto 0);
   signal pop_count   : std_logic_vector(3 downto 0) := (others => '0'); --current read transfer counter (words)
   signal get_rd_addr	: std_logic := '0'; --do pop flag
   signal rd_req_addr_i	: std_logic := '0';

  signal NPI_RDcols_count           : std_logic_vector(31 downto 0);
  signal NPI_RdFIFO_Pop_i    : std_logic;
  signal Output_valid_r0  		      : std_logic := '0';
  signal Output_valid_r1  		      : std_logic := '0';
  
	signal npi_rd_state     : std_logic_vector(0 to 1);	
	constant IDLE 			: std_logic_vector(0 to 1) := "00";
	constant GET_ADDR		: std_logic_vector(0 to 1) := "01";
	constant FIFO_POP 	: std_logic_vector(0 to 1) := "10";
	constant DONE		 	: std_logic_vector(0 to 1) := "11";


begin

	ChipScope <= Output_valid_r1 & rd_addr_ack & npi_rd_state & --NPI_RdFIFO_Pop_i
					 xfer_read & rd_xfer_done_i & rd_req_addr_i & Output_ready & --rd_addr_ack & --
					"0000" & pop_count &
					--CONV_STD_LOGIC_VECTOR(rd_words,8) &
					NPI_RdFIFO_Data(31 downto 16) &
					NPI_RDAddr_count_i;


rd_req_addr <= rd_req_addr_i and Output_ready;
rd_xfer_done <= rd_xfer_done_i ;
NPI_RdFIFO_Pop <= NPI_RdFIFO_Pop_i;

rd_block_bytes <= 4 when (rd_block_size = X"0" and C_NPI_DATA_WIDTH = 32) else -- 0x0 = Word transfers (32-bit NPI only)
							8 when (rd_block_size = X"0" and C_NPI_DATA_WIDTH = 64) else -- 0x0 = Double-word transfers (64-bit NPI only)
							16 when rd_block_size = X"1" else -- 0x1 = 4-word cache-line transfer
							32 when rd_block_size = X"2" else -- 0x2 = 8-word cache-line transfers
							64 when rd_block_size = X"3" else -- 0x3 = 16-word burst transfers
							128 when rd_block_size = X"4" else -- 0x4 = 32-word burst transfers
							256 when rd_block_size = X"5" else 4; -- 0x5 = 64-word burst transfers


NPI_CLK_REGS : process(NPI_Clk)
begin
	if (NPI_Clk'event and NPI_Clk = '1') then
		row_counter_r <= row_counter;
		--RdFIFO latency issue
		if (NPI_RdFIFO_Latency = "01") then --latency = 1
			Output_valid_r1 <= NPI_RdFIFO_Pop_i;
		else --latency = 2
			Output_valid_r0 <= NPI_RdFIFO_Pop_i;
			Output_valid_r1 <= Output_valid_r0;
		end if;
  end if;
end process NPI_CLK_REGS;

Output_valid <= NPI_RdFIFO_Pop_i when (NPI_RdFIFO_Latency = "00") else Output_valid_r1; --workaround NPI_RdFIFO_Pop_i when (NPI_RdFIFO_Latency = "00")

NPI_READ_ENGINE: process (rst_global, NPI_Clk)
begin
  if (rst_global = '1') then
		
rd_req_addr_i <= '0';
		npi_rd_state <= IDLE;
		rd_xfer_done_i <= '1'; --done flag
		rd_data_cnt <= 0;
  elsif (NPI_Clk'event and NPI_Clk = '1') then
  		--debug counter
		if (xfer_read = '0') then
			rd_data_cnt <= 0;
		elsif (NPI_AddrAck = '1' and NPI_RNW = '1') then
			rd_data_cnt <= rd_data_cnt + rd_block_bytes;
		end if;
  
	 case npi_rd_state is

      when IDLE =>
			rd_req_addr_i <= '0';
			if (xfer_read = '1' and get_rd_addr = '1') then  --start flag
				npi_rd_state <= GET_ADDR; --next state
				rd_req_addr_i <= '1';
				rd_xfer_done_i <= '0'; --done flag
			end if;

      when GET_ADDR =>
			rd_req_addr_i <= '1';
			if (rd_addr_ack = '1') then
				rd_req_addr_i <= '0';
				if (get_rd_addr = '1') then
					npi_rd_state <= FIFO_POP; --next state
				end if;
			end if;
			
      when FIFO_POP =>
		  if (rd_words = rd_data_cnt) then --last Addr
				npi_rd_state <= DONE; --next state
		  elsif (get_rd_addr = '1') then  --current transfer counter (words) NPI_RdFIFO_Pop_i = '1' and 
				npi_rd_state <= GET_ADDR; --next state
		  end if;		
		  
		 when DONE =>
			if (xfer_read = '0' or rd_loop = '1') then
				npi_rd_state <= IDLE; --next state
			else
				rd_xfer_done_i <= '1'; --done flag
			end if;	
		  
      when others => null; --DO NOTHING
     end case;		

  end if;
end process NPI_READ_ENGINE;

NPI_RDAddr_count <= NPI_RDAddr_count_i;

CMD_PIPELINE_COUNTING: process (NPI_Clk)
begin
	if (NPI_Clk'event and NPI_Clk = '1') then
	get_rd_addr <= '1';
		if (xfer_read = '0') then
			pop_count <= (others => '0'); --reset fifo occupancy counter
			get_rd_addr <= '1';
		elsif (rd_xfer_done_i = '1') then
			get_rd_addr <= '0'; --stop everything
--		elsif (NPI_RdFIFO_Pop_i = '1' and rd_addr_ack = '1') then
			--do nothing
--		elsif (rd_addr_ack = '1') then --increment
--			case pop_count is
--				when "0000" =>
--					pop_count <= "0001";
--					get_rd_addr <= '1';
--				when "0001" =>
--					pop_count <= "0010";
--					get_rd_addr <= '1';
--				when "0010" =>
--					pop_count <= "0011";
--					get_rd_addr <= '1';
--				when "0011" =>
--					pop_count <= "0100";
--					get_rd_addr <= '1';
--				when "0100" =>
--					pop_count <= "0101";
--					get_rd_addr <= '1';
--				when "0101" =>
--					pop_count <= "0110";
--					get_rd_addr <= '1';
--				when "0110" =>
--					pop_count <= "0111";
--					get_rd_addr <= '1';
--				when others =>
--					pop_count <= "1000";
--					get_rd_addr <= '0'; --full, do not do it any more
--			end case;
--			
--      elsif (NPI_RdFIFO_Pop_i = '1') then --decrement
--			get_rd_addr <= '1';
--			case pop_count is
--				when "0010" =>
--					pop_count <= "0001";
--				when "0011" =>
--					pop_count <= "0010";
--				when "0100" =>
--					pop_count <= "0011";
--				when "0101" =>
--					pop_count <= "0100";
--				when "0110" =>
--					pop_count <= "0101";
--				when "0111" =>
--					pop_count <= "0110";
--				when "1000" =>
--					pop_count <= "0111";
--				when others =>
--					pop_count <= "0000";
--			end case;
--		else
		end if;
  end if;
end process CMD_PIPELINE_COUNTING;

NPI_RdFIFO_Pop_i <= not NPI_RdFIFO_Empty when (xfer_read = '1' and Output_ready = '1') else '0';

NPI_RD_ADDR_INCR: process (rst_global, NPI_Clk)
begin
  if (NPI_Clk'event and NPI_Clk = '1') then
		if (xfer_read = '0' or (rd_xfer_done_i = '1' and rd_loop = '1')) then
			NPI_RDAddr_count_i <= rd_start_addr; --to start address
			NPI_RDcols_count <= rd_start_addr + CONV_STD_LOGIC_VECTOR(rd_block_bytes,32); --to next col
			row_counter <= 0; --reset counter
      elsif (rd_addr_ack = '1' and  NPI_RNW = '1') then --new address ready
			if (row_counter_r = rows) then
				row_counter <= 0; --reset counter
				NPI_RDAddr_count_i <= NPI_RDcols_count; --next Addr
				NPI_RDcols_count <= NPI_RDcols_count + CONV_STD_LOGIC_VECTOR(rd_block_bytes,32); --to next col
			elsif (use_rd_jump = '1') then --transpose
				row_counter <= row_counter + 1;
				NPI_RDAddr_count_i <= NPI_RDAddr_count_i + read_jump; --next Addr
			else --burst read
				NPI_RDAddr_count_i <= NPI_RDAddr_count_i + rd_block_bytes; --next Addr
			end if;
		end if;
  end if;
end process NPI_RD_ADDR_INCR;

OUTPUT_NO_SWAP:
	if (C_SWAP_OUTPUT = 0) generate
	 begin
		Output_data <= NPI_RdFIFO_Data;
	end generate;

OUTPUT_SWAP:
	if (C_SWAP_OUTPUT = 1) generate
	 begin 
	  OUTPUT_BYTE_SWAP : entity xps_npi_dma_v3_00_a.byte_swap
		 generic map
		 (
			C_WIDTH => C_NPI_DATA_WIDTH
		 )
		 port map
		 (
			input  => NPI_RdFIFO_Data,
			output => Output_data
		 );
 end generate;
 
end Behavioral;

