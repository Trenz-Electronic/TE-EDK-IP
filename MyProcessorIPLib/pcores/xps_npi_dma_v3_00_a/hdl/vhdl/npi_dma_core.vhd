-----------------------------------------------------
--
--      Filename: imaging.vhd
--      Version:  2.0
--      Author:   Ales Gorkic
--      Company:  KOLT
--      Phone:    031 345993
--      Email:   ales.gorkic@fs.uni-lj.si
--      Change History:
--      Date        Version     Comments
--      10.07.08      0.1       Genesis
--
-------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x"
--      reset signals:                          "rst", "rst_n"
--      generics/parameters:                    "C_*"
--      user defined types:                     "*_TYPE"
--      state machine next state:               "*_ns"
--      state machine current state:            "*_cs"
--      combinatorial signals:                  "*_cmb"
--      pipelined or register delay signals:    "*_d#"
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce"
--      internal version of output port         "*_i"
--      ports:                                  - Names begin with Uppercase
--      processes:                              "*_PROCESS"
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
-- Definition of Generics:
--      C_FAMILY                    -- Target FGPA family
--
-- Definition of Ports:
--      RS232_RX                    -- connection to RS232 RX 				
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Libraries
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
 
library unisim;
use unisim.vcomponents.all;
 
library xps_npi_dma_v3_00_a;
use xps_npi_dma_v3_00_a.all;

-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity npi_dma_core is
  generic (
    C_NPI_DATA_WIDTH  : integer := 64; --32 or 64 bit NPI bus
	 C_INCLUDE_WRITE_PATH : integer := 1; --write path switch
	 C_SWAP_INPUT : integer := 1; --byte swappping switch
	 C_INCLUDE_READ_PATH : integer := 1; --read path switch
	 C_SWAP_OUTPUT : integer := 1; --byte swappping switch
	 C_PADDING_BE : integer := 1 --0x00(0) or 0xFF(1) last packet padding
    );
  port (    
	 SYS_Clk              : in  std_logic;
    SYS_Rst              : in  std_logic;
		  
	 Reg_in_0 				 : in std_logic_vector(0 to 31);
	 Reg_in_1 				 : in std_logic_vector(0 to 31);
	 Reg_in_2 				 : in std_logic_vector(0 to 31);
	 Reg_in_3 				 : in std_logic_vector(0 to 31);
	 Reg_in_4 				 : in std_logic_vector(0 to 31);
	 Reg_in_5 				 : in std_logic_vector(0 to 31);
	 Reg_out_0 				 : out std_logic_vector(0 to 31);
	 Reg_out_1 				 : out std_logic_vector(0 to 31);
	 Reg_out_2 				 : out std_logic_vector(0 to 31);
	 
    Interrupt            : out std_logic_VECTOR(0 to 7);
    
    NPI_Clk              : in  std_logic;

   Capture_data		    	    : in std_logic_vector(0 to C_NPI_DATA_WIDTH-1);
   Capture_valid  		      : in std_logic := '0';
   Capture_ready  		      : out std_logic := '0';

   Output_data		    	    : out std_logic_vector(0 to C_NPI_DATA_WIDTH-1);
   Output_valid  		      : out std_logic := '0';
   Output_ready  		      : in std_logic := '1';

    NPI_Addr             : out std_logic_vector (31 downto 0) := (others => '0');
    NPI_AddrReq          : out std_logic := '0';             
    NPI_AddrAck          : in  std_logic;
    NPI_RNW              : out std_logic := '0';             
    NPI_Size             : out std_logic_vector (3 downto 0) := "0000";
	 NPI_RdModWr          : out std_logic := '0';  --new ONLY VALID FOR ECC           
    NPI_WrFIFO_Data      : out std_logic_vector (C_NPI_DATA_WIDTH-1 downto 0) := (others => '0');
    NPI_WrFIFO_BE        : out std_logic_vector (C_NPI_DATA_WIDTH/8-1 downto 0) := (others => '0');
    NPI_WrFIFO_Push      : out std_logic := '0';
    NPI_RdFIFO_Data      : in std_logic_vector (C_NPI_DATA_WIDTH-1 downto 0) := (others => '0');
	 NPI_RdFIFO_Pop       : out std_logic := '0';           
    NPI_RdFIFO_RdWdAddr  : in std_logic_vector (3 downto 0);
	 NPI_WrFIFO_Empty     : in std_logic := '0';  --new            	 
    NPI_WrFIFO_AlmostFull : in  std_logic;             
    NPI_WrFIFO_Flush     : out std_logic := '0';             
    NPI_RdFIFO_Empty     : in  std_logic;             
    NPI_RdFIFO_Flush     : out std_logic := '0'; 
    NPI_RdFIFO_Latency   : in std_logic_vector (1 downto 0); --new
	 NPI_InitDone  : in std_logic := '0';  --new  

    ChipScope        	: out std_logic_vector(63 downto 0) := (others => '0')
    );

end entity npi_dma_core;

------------------------------------------------------------------------------
-- Architecture section
------------------------------------------------------------------------------

architecture IMP of npi_dma_core is

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------


------------------------------------------
-- Signals declaration
------------------------------------------
   signal	rst                 : std_logic;	              --master reset from DCR register
   signal	rst_global          : std_logic;	              --reset from DCR register and SYS_rst


-- NPI implementation signals
	signal npi_addr_state   : std_logic_vector(0 to 1);	
	constant IDLE 			: std_logic_vector(0 to 1) := "00";
	constant GET_RDADDR		: std_logic_vector(0 to 1) := "01";
	constant GET_WRADDR		: std_logic_vector(0 to 1) := "10";
	constant DONE		 	: std_logic_vector(0 to 1) := "11";
	constant ADDR_ACK	 	: std_logic_vector(0 to 1) := "11";

	signal use_rd_jump 	: std_logic := '0'; --flag for using jump (used in transpose)

  signal Output_data_i		    	    : std_logic_vector(C_NPI_DATA_WIDTH-1 downto 0);
  signal read_jump : integer := 0; --gap between consecutive read packets
  signal rows : integer := 0; --number of rows
  signal wr_start_addr      : std_logic_vector(31 downto 0) := (others => '0');
  signal rd_start_addr      : std_logic_vector(31 downto 0) := (others => '0');
  signal wr_last_addr_i  : std_logic_vector(31 downto 0) := (others => '0');
  signal wr_last_addr  : std_logic_vector(31 downto 0) := (others => '0');
  signal rd_words  : integer := 0;
  signal xfer_read           : std_logic := '0'; --read flag
  signal xfer_write           : std_logic := '0'; --write flag
  signal wr_loop           : std_logic := '0'; --internal counter loopback
  signal rd_loop           : std_logic := '0'; --internal counter loopback
  signal rd_xfer_done            : std_logic := '0'; --done flag
  signal wr_xfer_done            : std_logic := '0'; --done flag
  signal wr_req_addr         : std_logic := '0'; --request address flag
  signal wr_req_addr_p        : std_logic := '0'; --request address flag pending register
  signal wr_addr_ack        : std_logic := '0'; --ackonwledge address flag
  signal rd_addr_ack        : std_logic := '0'; --ackonwledge address flag
  signal rd_req_addr         : std_logic := '0'; --request address flag
  signal xfer_status          : std_logic_vector(0 to 3) := "0000";
  signal wr_block_size       : std_logic_vector(0 to 3) := "0000";
  signal wr_fifo_rst        : std_logic := '0'; --fifo reset flag 
  signal rd_fifo_rst        : std_logic := '0'; --fifo reset flag 
  signal rd_block_size       : std_logic_vector(0 to 3) := "0000";

  signal NPI_WRAddr_count           : std_logic_vector(31 downto 0);
  signal NPI_WRAddr_count_r           : std_logic_vector(31 downto 0);
  signal NPI_RDAddr_count           : std_logic_vector(31 downto 0);
  signal NPI_Addr_i           : std_logic_vector(31 downto 0);
  signal NPI_RdFIFO_Pop_i    : std_logic;
  signal NPI_RNW_i				 : std_logic;
  signal NPI_AddrReq_i        : std_logic;
 signal Output_valid_i  		      : std_logic := '0';

--testing
	signal ChipScope_a : std_logic_vector(63 downto 0); --preregister
  signal NPI_WrFIFO_AlmostFull_r         : std_logic := '0';


------------------------------------------
-- Component declaration
------------------------------------------


------------------------------------------
-- Implementation
------------------------------------------

begin

------------------------------------------
-- Signal connections
------------------------------------------           

	--Chipscope trigger
	--ChipScopeData <= NPI_WrFIFO_BE_i & NPI_WRAddr_count & NPI_WrFIFO_Data_i; npi_wr_state
--	ChipScope <= Output_valid_i & Output_data_i(62 downto 0);

--  ChipScope <= 	Output_valid_i & rd_req_addr & xfer_read & Capture_valid & 
--							rd_xfer_done & wr_req_addr_p & '0' & NPI_AddrAck & 
--							NPI_AddrReq_i & xfer_write & NPI_RNW_i & NPI_RdFIFO_Empty &
--							NPI_RdFIFO_Pop_i & "000" &
--							Output_data_i(15 downto 0) &
----							Capture_data(16 to 31) &
----							CONV_STD_LOGIC_VECTOR(rd_data_cnt,16) &
----							NPI_RDAddr_count(15 downto 0);
----							NPI_WrFIFO_Data_i(31 downto 16);--16bits
--							NPI_Addr_i; --32bits
							
	
	Output_valid <= Output_valid_i;

  rst_global <= rst or SYS_Rst or (not NPI_InitDone);
	
	Capture_ready <= not wr_xfer_done;

	--interrupt
	Interrupt(7) <= wr_xfer_done;
	Interrupt(6) <= rd_xfer_done;
	Interrupt(5) <= NPI_WrFIFO_AlmostFull_r;
	Interrupt(0 to 4) <= (others => '0');
  
  
  		--registers slicing
		rst <= Reg_in_0(31); --master reset
		wr_fifo_rst <= Reg_in_0(30);	--signal to reset NPI fifo
		rd_fifo_rst <= Reg_in_0(29);	--signal to reset NPI fifo
		wr_loop <= Reg_in_0(28);	--signal for continuous NPI transfer
		rd_loop <= Reg_in_0(27);	--signal for continuous NPI transfer
	--	wr_test <= Reg_in_0(26);	--signal to set test mode (32bit counter)  NOT USED ANY MORE
		xfer_write <= Reg_in_0(25);	--signal to set write mode  
		xfer_read <= Reg_in_0(24);	--signal to set read mode  
		wr_block_size <= Reg_in_0(20 to 23); --wr xfer block size
		rd_block_size <= Reg_in_0(16 to 19); --rd xfer block size
		use_rd_jump <= Reg_in_0(15); --flag for using jump (used in transpose)
	  
	  wr_last_addr <= wr_last_addr_i;
		
		rd_words <= CONV_INTEGER(Reg_in_4);
		read_jump <= CONV_INTEGER(Reg_in_5(0 to 15));  --read xfer jump bytes
		rows <= CONV_INTEGER(Reg_in_5(16 to 31));  --read xfer jump bytes
------------------------------------------
-- Processes
------------------------------------------
	--to IPIF
SYS_CLK_REGS : process(SYS_Clk)
begin
	if (SYS_Clk'event and SYS_Clk = '1') then
      Reg_out_0(31) <= wr_xfer_done; -- NPI xfer done
      Reg_out_0(30) <= rd_xfer_done; -- NPI xfer done
      Reg_out_0(24 to 27) <= xfer_status; --NPI transfer status
		Reg_out_1 <= NPI_WRAddr_count; --current address
		Reg_out_2 <= NPI_RDAddr_count; --current address
		NPI_WrFIFO_AlmostFull_r <= NPI_WrFIFO_AlmostFull;
		wr_last_addr_i <= wr_start_addr+CONV_INTEGER(Reg_in_2)-C_NPI_DATA_WIDTH/8;
  end if;
end process SYS_CLK_REGS;
		

NPI_CLK_REGISTERS : process(NPI_Clk)
begin
	if (NPI_Clk'event and NPI_Clk = '1') then
	wr_start_addr <= Reg_in_1; --NPI transfer start address
	rd_start_addr <= Reg_in_3; --NPI transfer start address
	  NPI_WrFIFO_Flush <= rst or SYS_Rst or wr_fifo_rst;
	  NPI_RdFIFO_Flush <= rst or SYS_Rst or rd_fifo_rst;
	end if;
end process NPI_CLK_REGISTERS;

	  NPI_AddrReq <= NPI_AddrReq_i;

NPI_Addr <= NPI_Addr_i;

------------------------------------------
-- NPI Address Arbiter implementation
------------------------------------------

REGISTER_ADDR_REQ : process (rst_global, NPI_Clk)
begin
  if (NPI_Clk'event and NPI_Clk = '1') then
	if (xfer_write = '0') then --reset
		wr_req_addr_p <= '0';
	elsif (wr_req_addr = '1') then --request
		wr_req_addr_p <= '1';
	elsif (wr_addr_ack = '1') then --acqknowledge
		wr_req_addr_p <= '0';
	end if;
  end if;
end process REGISTER_ADDR_REQ;

NPI_ADDR_WRITE: process (rst_global, NPI_Clk)
begin
  if (rst_global = '1') then
      NPI_AddrReq_i <= '0';  --request address down
		NPI_RNW_i <= '0';
		npi_addr_state <= IDLE; --next state
		wr_addr_ack <= '0';
		rd_addr_ack <= '0';	
  elsif (NPI_Clk'event and NPI_Clk = '1') then
	wr_addr_ack <= '0';
	rd_addr_ack <= '0';	
	case npi_addr_state is
	
		when IDLE =>
			npi_addr_state <= IDLE; --current state
			NPI_AddrReq_i <= '0';  --request address down
			if (xfer_write = '0' and xfer_read = '0') then
			  NPI_WRAddr_count_r <= wr_start_addr;
			  NPI_RNW_i <= '0';
			elsif (wr_req_addr_p = '1') then --write addess
			  NPI_Addr_i <= NPI_WRAddr_count_r;
			  NPI_RNW_i <= '0';
			  NPI_Size <= wr_block_size;
			  npi_addr_state <= GET_WRADDR; --next state
		  elsif (rd_req_addr = '1') then --read addess
			  NPI_Addr_i <= NPI_RDAddr_count;
			  NPI_RNW_i <= '1';
			  NPI_Size <= rd_block_size;
			  npi_addr_state <= GET_RDADDR; --next state
			end if;
		 
		 when GET_RDADDR =>
			npi_addr_state <= GET_RDADDR; --current state
			NPI_AddrReq_i <= '1';  --requesting address
			if (NPI_AddrAck = '1') then
				NPI_AddrReq_i <= '0';  --request address down
				npi_addr_state <= ADDR_ACK; --next state
				rd_addr_ack <= '1';
			end if;	

		 when GET_WRADDR =>
			npi_addr_state <= GET_WRADDR; --current state
			NPI_AddrReq_i <= '1';  --requesting address
			if (NPI_AddrAck = '1') then
				NPI_AddrReq_i <= '0';  --request address down
				npi_addr_state <= ADDR_ACK; --next state
				wr_addr_ack <= '1';
				NPI_WRAddr_count_r <= NPI_WRAddr_count; --register current address
			end if;

		 when ADDR_ACK =>
			npi_addr_state <= IDLE; --next state

      when others => 
			npi_addr_state <= IDLE; --next state

     end case;			
		
  end if;
end process NPI_ADDR_WRITE;

NPI_RNW <= NPI_RNW_i;

NPI_RdFIFO_Pop <= NPI_RdFIFO_Pop_i;

Output_data <= Output_data_i;
------------------------------------------
-- Port Maps
------------------------------------------
GEN_WRITE_PATH:
if (C_INCLUDE_WRITE_PATH = 1) generate
	 begin 
	  WRITE_PATH : entity xps_npi_dma_v3_00_a.dma_write_path
	 generic map( C_NPI_DATA_WIDTH => C_NPI_DATA_WIDTH,
				C_SWAP_INPUT => C_SWAP_INPUT,
				C_PADDING_BE => C_PADDING_BE
				)
    Port map(  rst_global 		=> rst_global,
				SYS_Clk				=> SYS_Clk,
            NPI_Clk 				=> NPI_Clk, 			
			   NPI_WrFIFO_Data 	=> NPI_WrFIFO_Data, 
				NPI_WrFIFO_BE 		=> NPI_WrFIFO_BE, 	
				NPI_WrFIFO_Push 	=> NPI_WrFIFO_Push,
			                      
				Capture_data 	=> Capture_data, 	
				Capture_valid 	=> Capture_valid, 	
                           
				xfer_write 		=> xfer_write, 		
				wr_loop 			=> wr_loop, 			
				wr_block_size 	=> wr_block_size, 
				wr_start_addr 	=> wr_start_addr, 
				wr_last_addr 	=> wr_last_addr, 	
				wr_addr_ack    => wr_addr_ack,    
                           
				wr_xfer_done     => wr_xfer_done,    
				NPI_WRAddr_count => NPI_WRAddr_count,
				wr_req_addr      => wr_req_addr,     
				xfer_status      => xfer_status,     
                                
				ChipScope        => Chipscope    
			  );
 end generate;
 
GEN_READ_PATH:
if (C_INCLUDE_READ_PATH = 1) generate
	 begin 
	  READ_PATH : entity xps_npi_dma_v3_00_a.dma_read_path
	 generic map( C_NPI_DATA_WIDTH => C_NPI_DATA_WIDTH,
				C_SWAP_OUTPUT => C_SWAP_OUTPUT
				)
    Port map(  rst_global 		=> rst_global,
            NPI_Clk 				=> NPI_Clk, 			
				
				xfer_read          	=> xfer_read,          
				rd_start_addr        => rd_start_addr,      
				rd_addr_ack          => rd_addr_ack,        
				rd_block_size        => rd_block_size,      
				read_jump 		      => read_jump, 		    
				rows 				      => rows,
				rd_words					=> rd_words,	
				NPI_RdFIFO_Data      => NPI_RdFIFO_Data,    
				NPI_RdFIFO_RdWdAddr  => NPI_RdFIFO_RdWdAddr,
				NPI_RdFIFO_Empty     => NPI_RdFIFO_Empty,   
				NPI_RdFIFO_Latency   => NPI_RdFIFO_Latency, 
				rd_loop              => rd_loop,            
				NPI_RNW              => NPI_RNW_i,            
				NPI_AddrAck          => NPI_AddrAck,        
				use_rd_jump 	      => use_rd_jump, 	    
				                        
				rd_xfer_done         => rd_xfer_done,      
				NPI_RdFIFO_Pop       => NPI_RdFIFO_Pop_i,    
				rd_req_addr          => rd_req_addr,       
				NPI_RDAddr_count     => NPI_RDAddr_count,  
				                                          
				Output_data		      => Output_data_i,		   
				Output_valid  		   => Output_valid_i, 		
				Output_ready  		   => Output_ready				
				                        
--				ChipScope        => Chipscope    
			  );
 end generate;
 

end IMP;

