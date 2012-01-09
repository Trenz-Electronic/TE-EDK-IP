----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:56:24 01/18/2010 
-- Design Name: 
-- Module Name:    dma_write_path - Behavioral 
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

entity dma_write_path is
	 Generic( C_NPI_DATA_WIDTH  : integer := 64; --32 or 64 bit NPI bus
				C_SYNCHRONOUS_INPUT : integer := 0; --the inpur is NPI_Clk synchronous (more bandwidth using burst)
				C_SWAP_INPUT : integer := 1; --byte swappping switch
				C_PADDING_BE : integer := 1 --0x00(0) or 0xFF(1) last packet padding
				);
    Port (  rst_global : in  STD_LOGIC;
				SYS_Clk              : in  std_logic;
            NPI_Clk : in  STD_LOGIC;
			   NPI_WrFIFO_Data      : out std_logic_vector (C_NPI_DATA_WIDTH-1 downto 0) := (others => '0');
				NPI_WrFIFO_BE        : out std_logic_vector (C_NPI_DATA_WIDTH/8-1 downto 0) := (others => '0');
				NPI_WrFIFO_Push      : out std_logic := '0';
			   
				Capture_data		   : in std_logic_vector(0 to C_NPI_DATA_WIDTH-1);
				Capture_valid  		: in std_logic := '0';

				xfer_write           : in std_logic := '0'; --write flag
				wr_loop             : in std_logic := '0'; --internal counter loopback
				wr_block_size       : in std_logic_vector(0 to 3) := "0000";
				wr_start_addr      :  in std_logic_vector(31 downto 0) := (others => '0');
				wr_last_addr  			: in std_logic_vector(31 downto 0) := (others => '0');
				wr_addr_ack        : in std_logic := '0'; --ackonwledge address flag

				wr_xfer_done         : out std_logic := '0'; --done flag
				NPI_WRAddr_count     : out std_logic_vector(31 downto 0);
				wr_req_addr          : out std_logic := '0'; --request address flag
				xfer_status          : out std_logic_vector(0 to 3) := "0000";

				ChipScope        	: out std_logic_vector(63 downto 0) := (others => '0')

			  );
end dma_write_path;

architecture Behavioral of dma_write_path is

  signal NPI_BE_PADDING  : std_logic_vector(C_NPI_DATA_WIDTH/8-1 downto 0);
  signal Capture_data_r      : std_logic_vector(0 to C_NPI_DATA_WIDTH-1) := (others => '0');
  signal Capture_data_i      : std_logic_vector(0 to C_NPI_DATA_WIDTH-1) := (others => '0');
  signal NPI_WRAddr_count_i     : std_logic_vector(31 downto 0);
  signal NPI_WrFIFO_Push_i    : std_logic;
  signal NPI_WrFIFO_Push_r0         : std_logic := '0'; --request address flag
  signal NPI_WrFIFO_Push_r1         : std_logic := '0'; --request address flag
  signal NPI_WrFIFO_Data_buf  : std_logic_vector (C_NPI_DATA_WIDTH-1 downto 0) := (others => '0');
  signal wr_block_bytes   : integer range 0 to 256 := 0; --current transfer counter (words)
  signal wr_block_bytes_r   : integer range 0 to 256 := 0; --current transfer counter (words)
  signal wr_block_bytes_minus   : integer range 0 to 256 := 0; --current transfer counter (words)
  signal xfer_wr_block_counter   : integer range 0 to 257 := 0; --current transfer counter (words)
  signal do_padding				: std_logic := '0'; --do padding flag
  signal wr_req_addr_i				: std_logic := '0'; --request address flag
  signal mux64_upper             : std_logic := '0'; --internal test flag
  signal wr_xfer_done_i            : std_logic := '0'; --done flag
  signal NPI_WrFIFO_BE_i      : std_logic_vector(C_NPI_DATA_WIDTH/8-1 downto 0);

   signal npi_wr_state     : std_logic_vector(0 to 1);
	constant IDLE 			: std_logic_vector(0 to 1) := "00";
	constant BLOCK_START	: std_logic_vector(0 to 1) := "01";
	constant GET_ADDR		: std_logic_vector(0 to 1) := "10";
	constant FIFO_PUSH 	: std_logic_vector(0 to 1) := "11";
   signal xfer_status_i          : std_logic_vector(0 to 3) := "0000";

begin

	ChipScope <= Capture_valid & NPI_WrFIFO_Push_i & npi_wr_state &
					 xfer_write & wr_xfer_done_i & wr_req_addr_i & wr_addr_ack &
					CONV_STD_LOGIC_VECTOR(xfer_wr_block_counter,8) &
					Capture_data(16 to 31) &
					NPI_WRAddr_count_i(15 downto 0) &
					wr_last_addr(15 downto 0);


--	ChipScope <= NPI_WRAddr_count_i & wr_last_addr;

	wr_req_addr <= wr_req_addr_i;

  NPI_BE_PADDING <= (others => '0') when C_PADDING_BE = 0 else (others => '1');


NPI_WRAddr_count <= NPI_WRAddr_count_i;
wr_xfer_done <= wr_xfer_done_i;
xfer_status <= xfer_status_i;
	
wr_block_bytes <= 4 when (wr_block_size = X"0" and C_NPI_DATA_WIDTH = 32) else -- 0x0 = Word transfers (32-bit NPI only)
							8 when (wr_block_size = X"0" and C_NPI_DATA_WIDTH = 64) else -- 0x0 = Double-word transfers (64-bit NPI only)
							16 when wr_block_size = X"1" else -- 0x1 = 4-word cache-line transfer
							32 when wr_block_size = X"2" else -- 0x2 = 8-word cache-line transfers
							64 when wr_block_size = X"3" else -- 0x3 = 16-word burst transfers
							128 when wr_block_size = X"4" else -- 0x4 = 32-word burst transfers
							256 when wr_block_size = X"5" else 4; -- 0x5 = 64-word burst transfers

SYS_CLK_REGS : process(SYS_Clk)
begin
	if (SYS_Clk'event and SYS_Clk = '1') then

  end if;
end process SYS_CLK_REGS;

NPI_CLK_REGS : process(NPI_Clk)
begin
	if (NPI_Clk'event and NPI_Clk = '1') then
		NPI_WrFIFO_Push_r0 <= Capture_valid;
		NPI_WrFIFO_Push_r1 <= NPI_WrFIFO_Push_r0;	
	   NPI_WrFIFO_BE <= NPI_WrFIFO_BE_i;
	   NPI_WrFIFO_Push <= NPI_WrFIFO_Push_i;
		NPI_WrFIFO_Data <= NPI_WrFIFO_Data_buf;
		Capture_data_r <= Capture_data_i;
		wr_block_bytes_r <= wr_block_bytes;
		wr_block_bytes_minus	<= wr_block_bytes-C_NPI_DATA_WIDTH/8;	
  end if;
end process NPI_CLK_REGS;


NPI_WRITE_ENGINE: process (rst_global, NPI_Clk)
begin
  if (rst_global = '1') then
		xfer_wr_block_counter <= 0;  --reset counter
		wr_req_addr_i <= '0';
		npi_wr_state <= IDLE;
      xfer_status_i <= "0000";
		wr_xfer_done_i <= '1';
		do_padding <= '0';
  elsif (NPI_Clk'event and NPI_Clk = '1') then

	 case npi_wr_state is
      when IDLE =>
        if (xfer_write = '1') then  --PPC sets start flag
			if (wr_loop='1' or xfer_status_i(3) = '0') then --continue
				wr_xfer_done_i <= '0';
				NPI_WRAddr_count_i <= wr_start_addr;
				xfer_wr_block_counter <= 0;  --reset counter
				npi_wr_state <= BLOCK_START; --next state
			else
			 --done
			end if;
        else
			NPI_WRAddr_count_i <= wr_start_addr;
			xfer_wr_block_counter <= 0;  --reset counter
          xfer_status_i <= "0000";   --reset status     
          wr_xfer_done_i <= '1';
        end if;

		when BLOCK_START	=>
			if (NPI_WRAddr_count_i <= wr_last_addr) then  --continue transfer until last address
--				if (wr_block_size = X"0") then --special case: req_addr asserted before data DOES NOT WORK
--					wr_req_addr_i <= '1';
--					npi_wr_state <= GET_ADDR; --next state
--				else
					npi_wr_state <= FIFO_PUSH; --next state
--				end if;
          else  --transfer completed
            wr_xfer_done_i <= '1';
				npi_wr_state <= IDLE; --next state
				xfer_status_i(3) <= '1';   --set status 
          end if;

      when GET_ADDR =>	--only valid for single beat	
			if (wr_addr_ack = '1') then
				npi_wr_state <= FIFO_PUSH; --next state
			end if;
		
      when FIFO_PUSH =>
			if (wr_req_addr_i = '1') then --BLOCK FINISHED
				npi_wr_state <= BLOCK_START; --next state
			end if;
		  
      when others => null; --DO NOTHING
     end case;		

	 --data counter
	 wr_req_addr_i <= '0';
	if (NPI_WrFIFO_Push_i = '1' and wr_xfer_done_i = '0') then
	  if (xfer_wr_block_counter = wr_block_bytes_minus) then --end of block
			xfer_wr_block_counter <= 0;  --reset counter
			NPI_WRAddr_count_i <= NPI_WRAddr_count_i + wr_block_bytes_r; --next block Addr
			wr_req_addr_i <= '1';
	  else
			xfer_wr_block_counter <= xfer_wr_block_counter + C_NPI_DATA_WIDTH/8;  --increment counter
	  end if;
	end if;
	
  end if;
end process NPI_WRITE_ENGINE;


NPI_PUSH_HANDLING: process (rst_global, NPI_Clk)
begin
  if (rst_global = '1') then
      NPI_WrFIFO_Push_i <= '0';
		mux64_upper <= '0';
  elsif (NPI_Clk'event and NPI_Clk = '1') then
		NPI_WrFIFO_Push_i <= '0'; --DEFAULT
--		if (do_padding = '1') then
--			NPI_WrFIFO_Push_i <= '1';
--		   NPI_WrFIFO_BE_i <= NPI_BE_PADDING;
      if (NPI_WrFIFO_Push_r0 = '1' and wr_xfer_done_i = '0') then
			NPI_WrFIFO_Push_i <= '1';
			NPI_WrFIFO_Data_buf <= Capture_data_r;		  
			NPI_WrFIFO_BE_i <= (others => '1');
      end if;
  end if;
end process NPI_PUSH_HANDLING;



INPUT_NO_SWAP:
	if (C_SWAP_INPUT = 0) generate
	 begin
		Capture_data_i   <= Capture_data; --no byte swapping
 end generate;


INPUT_SWAP:
	if (C_SWAP_INPUT = 1) generate
	 begin 
	  CAPTURE_BYTE_SWAP : entity xps_npi_dma_v3_00_a.byte_swap
		 generic map
		 (
			C_WIDTH => C_NPI_DATA_WIDTH
		 )
		 port map
		 (
			input  => Capture_data,
			output => Capture_data_i
		 );
 end generate;

end Behavioral;

