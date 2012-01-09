------------------------------------------------------------------------------
-- user_logic.vhd - entity/architecture pair
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.            **
-- **                                                                       **
-- ** Xilinx, Inc.                                                          **
-- ** XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS"         **
-- ** AS A COURTESY TO YOU, SOLELY FOR USE IN DEVELOPING PROGRAMS AND       **
-- ** SOLUTIONS FOR XILINX DEVICES.  BY PROVIDING THIS DESIGN, CODE,        **
-- ** OR INFORMATION AS ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE,        **
-- ** APPLICATION OR STANDARD, XILINX IS MAKING NO REPRESENTATION           **
-- ** THAT THIS IMPLEMENTATION IS FREE FROM ANY CLAIMS OF INFRINGEMENT,     **
-- ** AND YOU ARE RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE      **
-- ** FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY DISCLAIMS ANY              **
-- ** WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE               **
-- ** IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR        **
-- ** REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF       **
-- ** INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS       **
-- ** FOR A PARTICULAR PURPOSE.                                             **
-- **                                                                       **
-- ***************************************************************************
--
------------------------------------------------------------------------------
-- Filename:          user_logic.vhd
-- Version:           1.00.a
-- Description:       User logic.
-- Date:              Thu Sep 11 16:59:31 2008 (by Create and Import Peripheral Wizard)
-- VHDL Standard:     VHDL'93
------------------------------------------------------------------------------
-- Naming Conventions:
--   active low signals:                    "*_n"
--   clock signals:                         "clk", "clk_div#", "clk_#x"
--   reset signals:                         "rst", "rst_n"
--   generics:                              "C_*"
--   user defined types:                    "*_TYPE"
--   state machine next state:              "*_ns"
--   state machine current state:           "*_cs"
--   combinatorial signals:                 "*_com"
--   pipelined or register delay signals:   "*_d#"
--   counter signals:                       "*cnt*"
--   clock enable signals:                  "*_ce"
--   internal version of output port:       "*_i"
--   device pins:                           "*_pin"
--   ports:                                 "- Names begin with Uppercase"
--   processes:                             "*_PROCESS"
--   component instantiations:              "<ENTITY_>I_<#|FUNC>"
------------------------------------------------------------------------------

-- DO NOT EDIT BELOW THIS LINE --------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;

-- DO NOT EDIT ABOVE THIS LINE --------------------

--USER libraries added here

library xps_npi_dma_v3_00_a;
use xps_npi_dma_v3_00_a.all;

------------------------------------------------------------------------------
-- Entity section
------------------------------------------------------------------------------
-- Definition of Generics:
--   C_SLV_DWIDTH                 -- Slave interface data bus width
--   C_NUM_REG                    -- Number of software accessible registers
--   C_NUM_INTR                   -- Number of interrupt event
--
-- Definition of Ports:
--   Bus2IP_Clk                   -- Bus to IP clock
--   Bus2IP_Reset                 -- Bus to IP reset
--   Bus2IP_Data                  -- Bus to IP data bus
--   Bus2IP_BE                    -- Bus to IP byte enables
--   Bus2IP_RdCE                  -- Bus to IP read chip enable
--   Bus2IP_WrCE                  -- Bus to IP write chip enable
--   IP2Bus_Data                  -- IP to Bus data bus
--   IP2Bus_RdAck                 -- IP to Bus read transfer acknowledgement
--   IP2Bus_WrAck                 -- IP to Bus write transfer acknowledgement
--   IP2Bus_Error                 -- IP to Bus error response
--   IP2Bus_IntrEvent             -- IP to Bus interrupt event
------------------------------------------------------------------------------

entity user_logic is
  generic
  (
    -- ADD USER GENERICS BELOW THIS LINE ---------------
    --USER generics added here
	 C_NPI_DATA_WIDTH  : integer := 32; --32 or 64 bit NPI bus
	 C_SWAP_INPUT : integer := 0; --byte swappping switch
	 C_SWAP_OUTPUT : integer := 0; --byte swappping switch
	 C_PADDING_BE : integer := 1; --0x00(0) or 0xFF(1) last packet padding
	 C_INCLUDE_WRITE_PATH : integer := 1; --write path switch
	 C_INCLUDE_READ_PATH : integer := 1; --read path switch

    -- ADD USER GENERICS ABOVE THIS LINE ---------------

    -- DO NOT EDIT BELOW THIS LINE ---------------------
    -- Bus protocol parameters, do not add to or delete
    C_SLV_DWIDTH                   : integer              := 32;
    C_NUM_REG                      : integer              := 9;
    C_NUM_INTR                     : integer              := 8
    -- DO NOT EDIT ABOVE THIS LINE ---------------------
  );
  port
  (
    -- ADD USER PORTS BELOW THIS LINE ------------------
    --USER ports added here
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

    ChipScope        	: out std_logic_vector(63 downto 0) := (others => '0');

    -- ADD USER PORTS ABOVE THIS LINE ------------------

    -- DO NOT EDIT BELOW THIS LINE ---------------------
    -- Bus protocol ports, do not add to or delete
    Bus2IP_Clk                     : in  std_logic;
    Bus2IP_Reset                   : in  std_logic;
    Bus2IP_Data                    : in  std_logic_vector(0 to C_SLV_DWIDTH-1);
    Bus2IP_BE                      : in  std_logic_vector(0 to C_SLV_DWIDTH/8-1);
    Bus2IP_RdCE                    : in  std_logic_vector(0 to C_NUM_REG-1);
    Bus2IP_WrCE                    : in  std_logic_vector(0 to C_NUM_REG-1);
    IP2Bus_Data                    : out std_logic_vector(0 to C_SLV_DWIDTH-1);
    IP2Bus_RdAck                   : out std_logic;
    IP2Bus_WrAck                   : out std_logic;
    IP2Bus_Error                   : out std_logic;
    IP2Bus_IntrEvent               : out std_logic_vector(0 to C_NUM_INTR-1)
    -- DO NOT EDIT ABOVE THIS LINE ---------------------
  );

  attribute SIGIS : string;
  attribute SIGIS of Bus2IP_Clk    : signal is "CLK";
  attribute SIGIS of Bus2IP_Reset  : signal is "RST";

end entity user_logic;

------------------------------------------------------------------------------
-- Architecture section
------------------------------------------------------------------------------

architecture IMP of user_logic is

  --USER signal declarations added here, as needed for user logic

  ------------------------------------------
  -- Signals for user logic slave model s/w accessible register example
  ------------------------------------------
  signal slv_reg0                       : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_reg1                       : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_reg2                       : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_reg3                       : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_reg4                       : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_reg5                       : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_reg6                       : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_reg7                       : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_reg8                       : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_reg_write_sel              : std_logic_vector(0 to 8);
  signal slv_reg_read_sel               : std_logic_vector(0 to 8);
  signal slv_ip2bus_data                : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_read_ack                   : std_logic;
  signal slv_write_ack                  : std_logic;

begin

 --USER logic implementation added here

  ------------------------------------------
  -- Example code to read/write user logic slave model s/w accessible registers
  -- 
  -- Note:
  -- The example code presented here is to show you one way of reading/writing
  -- software accessible registers implemented in the user logic slave model.
  -- Each bit of the Bus2IP_WrCE/Bus2IP_RdCE signals is configured to correspond
  -- to one software accessible register by the top level template. For example,
  -- if you have four 32 bit software accessible registers in the user logic,
  -- you are basically operating on the following memory mapped registers:
  -- 
  --    Bus2IP_WrCE/Bus2IP_RdCE   Memory Mapped Register
  --                     "1000"   C_BASEADDR + 0x0
  --                     "0100"   C_BASEADDR + 0x4
  --                     "0010"   C_BASEADDR + 0x8
  --                     "0001"   C_BASEADDR + 0xC
  -- 
  ------------------------------------------
  slv_reg_write_sel <= Bus2IP_WrCE(0 to 8);
  slv_reg_read_sel  <= Bus2IP_RdCE(0 to 8);
  slv_write_ack     <= Bus2IP_WrCE(0) or Bus2IP_WrCE(1) or Bus2IP_WrCE(2) or Bus2IP_WrCE(3) or Bus2IP_WrCE(4) or Bus2IP_WrCE(5) or Bus2IP_WrCE(6) or Bus2IP_WrCE(7) or Bus2IP_WrCE(8);
  slv_read_ack      <= Bus2IP_RdCE(0) or Bus2IP_RdCE(1) or Bus2IP_RdCE(2) or Bus2IP_RdCE(3) or Bus2IP_RdCE(4) or Bus2IP_RdCE(5) or Bus2IP_RdCE(6) or Bus2IP_RdCE(7) or Bus2IP_RdCE(8);

  -- implement slave model software accessible register(s)
  SLAVE_REG_WRITE_PROC : process( Bus2IP_Clk ) is
  begin

    if Bus2IP_Clk'event and Bus2IP_Clk = '1' then
      if Bus2IP_Reset = '1' then
        slv_reg0 <= (others => '0');
        slv_reg1 <= (others => '0');
        slv_reg2 <= (others => '0');
        slv_reg3 <= (others => '0');
        slv_reg4 <= (others => '0');
        slv_reg5 <= (others => '0');
--        slv_reg6 <= (others => '0');
--        slv_reg7 <= (others => '0');
--        slv_reg8 <= (others => '0');
      else
        case slv_reg_write_sel is
          when "100000000" =>
            for byte_index in 0 to (C_SLV_DWIDTH/8)-1 loop
              if ( Bus2IP_BE(byte_index) = '1' ) then
                slv_reg0(byte_index*8 to byte_index*8+7) <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
              end if;
            end loop;
          when "010000000" =>
            for byte_index in 0 to (C_SLV_DWIDTH/8)-1 loop
              if ( Bus2IP_BE(byte_index) = '1' ) then
                slv_reg1(byte_index*8 to byte_index*8+7) <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
              end if;
            end loop;
          when "001000000" =>
            for byte_index in 0 to (C_SLV_DWIDTH/8)-1 loop
              if ( Bus2IP_BE(byte_index) = '1' ) then
                slv_reg2(byte_index*8 to byte_index*8+7) <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
              end if;
            end loop;
          when "000100000" =>
            for byte_index in 0 to (C_SLV_DWIDTH/8)-1 loop
              if ( Bus2IP_BE(byte_index) = '1' ) then
                slv_reg3(byte_index*8 to byte_index*8+7) <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
              end if;
            end loop;
          when "000010000" =>
            for byte_index in 0 to (C_SLV_DWIDTH/8)-1 loop
              if ( Bus2IP_BE(byte_index) = '1' ) then
                slv_reg4(byte_index*8 to byte_index*8+7) <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
              end if;
            end loop;
          when "000001000" =>
            for byte_index in 0 to (C_SLV_DWIDTH/8)-1 loop
              if ( Bus2IP_BE(byte_index) = '1' ) then
                slv_reg5(byte_index*8 to byte_index*8+7) <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
              end if;
            end loop;
          when "000000100" =>
--            for byte_index in 0 to (C_SLV_DWIDTH/8)-1 loop
--              if ( Bus2IP_BE(byte_index) = '1' ) then
--                slv_reg6(byte_index*8 to byte_index*8+7) <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
--              end if;
--            end loop;
          when "000000010" =>
--            for byte_index in 0 to (C_SLV_DWIDTH/8)-1 loop
--              if ( Bus2IP_BE(byte_index) = '1' ) then
--                slv_reg7(byte_index*8 to byte_index*8+7) <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
--              end if;
--            end loop;
          when "000000001" =>
--            for byte_index in 0 to (C_SLV_DWIDTH/8)-1 loop
--              if ( Bus2IP_BE(byte_index) = '1' ) then
--                slv_reg8(byte_index*8 to byte_index*8+7) <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
--              end if;
--            end loop;
          when others => null;
        end case;
      end if;
    end if;

  end process SLAVE_REG_WRITE_PROC;

  -- implement slave model software accessible register(s) read mux
  SLAVE_REG_READ_PROC : process( slv_reg_read_sel, slv_reg0, slv_reg1, slv_reg2, slv_reg3, slv_reg4, slv_reg5, slv_reg6, slv_reg7, slv_reg8 ) is
  begin

    case slv_reg_read_sel is
      when "100000000" => slv_ip2bus_data <= slv_reg0;
      when "010000000" => slv_ip2bus_data <= slv_reg1;
      when "001000000" => slv_ip2bus_data <= slv_reg2;
      when "000100000" => slv_ip2bus_data <= slv_reg3;
      when "000010000" => slv_ip2bus_data <= slv_reg4;
      when "000001000" => slv_ip2bus_data <= slv_reg5;
      when "000000100" => slv_ip2bus_data <= slv_reg6;
      when "000000010" => slv_ip2bus_data <= slv_reg7;
      when "000000001" => slv_ip2bus_data <= slv_reg8;
      when others => slv_ip2bus_data <= (others => '0');
    end case;

  end process SLAVE_REG_READ_PROC;

  ------------------------------------------
  -- Example code to drive IP to Bus signals
  ------------------------------------------
  IP2Bus_Data  <= slv_ip2bus_data when slv_read_ack = '1' else
                  (others => '0');

  IP2Bus_WrAck <= slv_write_ack;
  IP2Bus_RdAck <= slv_read_ack;
  IP2Bus_Error <= '0';


CORE_IMPLEMENTATION : entity xps_npi_dma_v3_00_a.npi_dma_core
	generic  map(
		C_NPI_DATA_WIDTH => C_NPI_DATA_WIDTH,
		C_SWAP_INPUT  => C_SWAP_INPUT, 
		C_SWAP_OUTPUT => C_SWAP_OUTPUT,
		 C_PADDING_BE =>  C_PADDING_BE,
		C_INCLUDE_WRITE_PATH => C_INCLUDE_WRITE_PATH,
		C_INCLUDE_READ_PATH  => C_INCLUDE_READ_PATH  
                           
		)
   Port  map(     
		SYS_Clk              =>  Bus2IP_Clk,  
		SYS_Rst              =>  Bus2IP_Reset,

		Reg_in_0 				 =>  slv_reg0,
		Reg_in_1 				 =>  slv_reg1,
		Reg_in_2 				 =>  slv_reg2,
		Reg_in_3				    =>  slv_reg3,
		Reg_in_4 				 =>  slv_reg4,
		Reg_in_5				    =>  slv_reg5,
		Reg_out_0 				 =>  slv_reg6,
		Reg_out_1 				 =>  slv_reg7,
		Reg_out_2 				 =>  slv_reg8,

		Interrupt            	=> IP2Bus_IntrEvent,
    
		NPI_Clk               	=> NPI_Clk,              
                                                
		Capture_data		    	=> Capture_data,		   
		Capture_valid  		 	=> Capture_valid,
		Capture_ready  		   => Capture_ready,
                                                  
		Output_data		     		=>	Output_data,		     	
		Output_valid  		  		=> Output_valid,
		Output_ready				=> Output_ready,		
                                                 
		NPI_Addr            		=> NPI_Addr,            	 
		NPI_AddrReq         		=> NPI_AddrReq,         	 
		NPI_AddrAck       	   => NPI_AddrAck,       	
		NPI_RNW          	    	=> NPI_RNW,          	   
		NPI_Size         	    	=> NPI_Size,         	   
		NPI_RdModWr      	    	=> NPI_RdModWr,      	   
		NPI_WrFIFO_Data    	  	=> NPI_WrFIFO_Data,    	
		NPI_WrFIFO_BE      	  	=> NPI_WrFIFO_BE,      	
		NPI_WrFIFO_Push    	 	=> NPI_WrFIFO_Push,    	
		NPI_RdFIFO_Data     	 	=> NPI_RdFIFO_Data,     	
		NPI_RdFIFO_Pop      	 	=> NPI_RdFIFO_Pop,      	
		NPI_RdFIFO_RdWdAddr 	 	=> NPI_RdFIFO_RdWdAddr, 	
		NPI_WrFIFO_Empty        =>	NPI_WrFIFO_Empty,      
		NPI_WrFIFO_AlmostFull   => NPI_WrFIFO_AlmostFull,
		NPI_WrFIFO_Flush        => NPI_WrFIFO_Flush,       
		NPI_RdFIFO_Empty        => NPI_RdFIFO_Empty,     
		NPI_RdFIFO_Flush        => NPI_RdFIFO_Flush,     
		NPI_RdFIFO_Latency  		=> NPI_RdFIFO_Latency,  	
		NPI_InitDone     => NPI_InitDone,  
                                                  
		ChipScope               => ChipScope            
    );                 


end IMP;
