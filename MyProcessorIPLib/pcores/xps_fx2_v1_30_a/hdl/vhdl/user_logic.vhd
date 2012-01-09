------------------------------------------------------------------------------
-- user_logic.vhd - entity/architecture pair
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 1995-2007 Xilinx, Inc.  All rights reserved.            **
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
-- Date:              Thu Apr 17 20:27:53 2008 (by Create and Import Peripheral Wizard)
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
library xps_fx2_v1_30_a;
use xps_fx2_v1_30_a.all;

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
	 C_TX_FIFO_KBYTE         : integer := 32;
    C_RX_FIFO_KBYTE         : integer := 2;
	 C_USE_ADDR_FIFO         : integer := 1;
	 C_TX_RDY_ALMOST_FULL : integer := 1;
	 C_TX_FIFO_CLK_180         : integer := 0;
    -- ADD USER GENERICS ABOVE THIS LINE ---------------

    -- DO NOT EDIT BELOW THIS LINE ---------------------
    -- Bus protocol parameters, do not add to or delete
    C_SLV_DWIDTH                   : integer              := 32;
    C_NUM_REG                      : integer              := 5;
    C_NUM_INTR                     : integer              := 8
    -- DO NOT EDIT ABOVE THIS LINE ---------------------
  );
  port
  (
    -- ADD USER PORTS BELOW THIS LINE ------------------
    --USER ports added here
	 USB_IFCLK            : in  std_logic;
    USB_SLRD             : out std_logic;
    USB_SLWR             : out std_logic;
    USB_FLAGA            : in std_logic;
    USB_FLAGB            : in std_logic;
    USB_FLAGC            : in std_logic;
	 USB_FLAGD            : in std_logic;
	 USB_SLOE             : out std_logic;
	 USB_PKTEND           : out std_logic;
	 USB_FIFOADR         : out std_logic_vector(1 downto 0); --"00"=EP2,"01"=EP4,"10"=EP6,11"=EP8
    USB_FD_T             : out std_logic := '1'; --OE active low
    USB_FD_O             : out std_logic_vector(7 downto 0) := (others => '0');
    USB_FD_I             : in std_logic_vector(7 downto 0);

    TX_FIFO_Clk             : in std_logic := '0';
    RX_FIFO_Clk             : in std_logic := '0';

    TX_FIFO_DIN             : in std_logic_vector(0 to 31) := (others => '0');
    TX_FIFO_VLD           : in std_logic := '0';
	 TX_FIFO_RDY				: out std_logic := '0';

    RX_FIFO_DOUT            : out std_logic_vector(0 to 31) := (others => '0');
	 RX_FIFO_VLD            : out	std_logic := '0';
    RX_FIFO_RDY				:	in	std_logic := '0';

    ChipScope        : out std_logic_vector(0 to 31) := (others => '0');
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
  signal   TX_FIFO_DIN_i             : std_logic_vector(0 to 31) := (others => '0');
  signal   TX_FIFO_DVALID_ce           : std_logic := '0';
  signal   TX_FIFO_DVALID_ce_r0         : std_logic := '0';
  signal   TX_FIFO_DVALID_ce_r1         : std_logic := '0';
  signal   TX_FIFO_VLD_i           : std_logic := '0';
  signal   RX_FIFO_DOUT_i            : std_logic_vector(0 to 31) := (others => '0');
  signal   RX_FIFO_RDY_i				: std_logic := '0';
  signal   RX_FIFO_OUT_EN_ce          : std_logic := '0';
  signal   RX_FIFO_OUT_EN_ce_r0          : std_logic := '0';
  signal   RX_FIFO_OUT_EN_ce_r1          : std_logic := '0';
  signal   RX_FIFO_OUT_EN_ack          : std_logic := '0';
  ------------------------------------------
  -- Signals for user logic slave model s/w accessible register example
  ------------------------------------------
  signal slv_reg0                       : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_reg1                       : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_reg2                       : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_reg3                       : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_reg4                       : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_reg_write_sel              : std_logic_vector(0 to 4);
  signal slv_reg_read_sel               : std_logic_vector(0 to 4);
  signal slv_ip2bus_data                : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal slv_read_ack                   : std_logic;
  signal slv_write_ack                  : std_logic;

  ------------------------------------------
  -- Signals for user logic interrupt example
  ------------------------------------------
  signal intr_counter                   : std_logic_vector(0 to C_NUM_INTR-1);

begin
	
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
  slv_reg_write_sel <= Bus2IP_WrCE(0 to 4);
  slv_reg_read_sel  <= Bus2IP_RdCE(0 to 4);
  slv_write_ack     <= Bus2IP_WrCE(0) or Bus2IP_WrCE(1) or Bus2IP_WrCE(2) or Bus2IP_WrCE(3) or Bus2IP_WrCE(4);
  slv_read_ack      <= Bus2IP_RdCE(0) or Bus2IP_RdCE(1) or Bus2IP_RdCE(2) or Bus2IP_RdCE(3) or Bus2IP_RdCE(4);

  -- implement slave model software accessible register(s)
  SLAVE_REG_WRITE_PROC : process( Bus2IP_Clk ) is
  begin

    if Bus2IP_Clk'event and Bus2IP_Clk = '1' then
	 	TX_FIFO_DVALID_ce <= '0'; --user
      if Bus2IP_Reset = '1' then
        slv_reg0 <= (others => '0');
        slv_reg1 <= (others => '0');
--        slv_reg2 <= (others => '0');
        slv_reg3 <= (others => '0');
--        slv_reg4 <= (others => '0');
      else
        case slv_reg_write_sel is
          when "10000" =>
            for byte_index in 0 to (C_SLV_DWIDTH/8)-1 loop
              if ( Bus2IP_BE(byte_index) = '1' ) then
                slv_reg0(byte_index*8 to byte_index*8+7) <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
              end if;
            end loop;
          when "01000" =>
            for byte_index in 0 to (C_SLV_DWIDTH/8)-1 loop
              if ( Bus2IP_BE(byte_index) = '1' ) then
                slv_reg1(byte_index*8 to byte_index*8+7) <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
              end if;
            end loop;
          when "00100" =>
--            for byte_index in 0 to (C_SLV_DWIDTH/8)-1 loop
--              if ( Bus2IP_BE(byte_index) = '1' ) then
--                slv_reg2(byte_index*8 to byte_index*8+7) <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
--              end if;
--            end loop;
          when "00010" =>
				TX_FIFO_DVALID_ce <= '1'; --user writes fifo
            for byte_index in 0 to (C_SLV_DWIDTH/8)-1 loop
              if ( Bus2IP_BE(byte_index) = '1' ) then
                slv_reg3(byte_index*8 to byte_index*8+7) <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
              end if;
            end loop;
          when "00001" =>
--            for byte_index in 0 to (C_SLV_DWIDTH/8)-1 loop
--              if ( Bus2IP_BE(byte_index) = '1' ) then
--                slv_reg4(byte_index*8 to byte_index*8+7) <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
--              end if;
--            end loop;
          when others => null;
        end case;
      end if;
    end if;

  end process SLAVE_REG_WRITE_PROC;

  -- implement slave model software accessible register(s) read mux
  SLAVE_REG_READ_PROC : process( slv_reg_read_sel, slv_reg0, slv_reg1, slv_reg2, slv_reg3, slv_reg4 ) is
  begin
	 RX_FIFO_OUT_EN_ce <= '0'; --user
    case slv_reg_read_sel is
      when "10000" => slv_ip2bus_data <= slv_reg0;
      when "01000" => slv_ip2bus_data <= slv_reg1;
      when "00100" => slv_ip2bus_data <= slv_reg2;
      when "00010" => slv_ip2bus_data <= slv_reg3;
      when "00001" =>
			RX_FIFO_OUT_EN_ce <= '1'; --user
			slv_ip2bus_data <= slv_reg4;
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


  --USER logic implementation added here
  
	slv_reg4 <= RX_FIFO_DOUT_i;
	RX_FIFO_DOUT <= RX_FIFO_DOUT_i;
	RX_FIFO_RDY_i <= RX_FIFO_RDY or RX_FIFO_OUT_EN_ack;
  ------------------------------------------
  -- Rising edge detect
  ------------------------------------------
  RX_FIFO_CLK_REGISTERS : process(RX_FIFO_Clk)
  begin
    if rising_edge(RX_FIFO_Clk) then
		RX_FIFO_OUT_EN_ce_r0 <= RX_FIFO_OUT_EN_ce;
		RX_FIFO_OUT_EN_ce_r1 <= RX_FIFO_OUT_EN_ce_r0;
		if (RX_FIFO_OUT_EN_ce_r1 < RX_FIFO_OUT_EN_ce_r0) then --rising edge
			RX_FIFO_OUT_EN_ack <= '1';
		else
			RX_FIFO_OUT_EN_ack <= '0';
		end if;
	 end if;
  end process RX_FIFO_CLK_REGISTERS;

  TX_FIFO_CLK_REGISTERS : process(TX_FIFO_Clk)
  begin
    if rising_edge(TX_FIFO_Clk) then
		TX_FIFO_DVALID_ce_r0 <= TX_FIFO_DVALID_ce;
		TX_FIFO_DVALID_ce_r1 <= TX_FIFO_DVALID_ce_r0;
		
		if (TX_FIFO_DVALID_ce_r1 < TX_FIFO_DVALID_ce_r0) then --rising edge
			--write from register
			TX_FIFO_VLD_i  <= '1';
			TX_FIFO_DIN_i  <=  slv_reg3;
		elsif (TX_FIFO_VLD = '1') then
			--write from TX_FIFO port
			TX_FIFO_VLD_i  <= '1';
			TX_FIFO_DIN_i  <=  TX_FIFO_DIN;			
		else --idle
			TX_FIFO_VLD_i  <= '0';
		end if;
	 end if;
  end process TX_FIFO_CLK_REGISTERS;
  
  ------------------------------------------
  -- Component instantiations
  ------------------------------------------
  CORE_IMPLEMENTATION : entity xps_fx2_v1_30_a.fx2_core
	generic  map(
		C_TX_FIFO_KBYTE => C_TX_FIFO_KBYTE,
		C_RX_FIFO_KBYTE => C_RX_FIFO_KBYTE,
		C_USE_ADDR_FIFO => C_USE_ADDR_FIFO,
		C_TX_RDY_ALMOST_FULL => C_TX_RDY_ALMOST_FULL,
		C_TX_FIFO_CLK_180 => C_TX_FIFO_CLK_180
		)
   Port  map(     
    SYS_Clk              =>  Bus2IP_Clk,  
    SYS_Rst              =>  Bus2IP_Reset,

	 Reg_in_0 				 =>  slv_reg0,
	 Reg_in_1 				 =>  slv_reg1,
	 Reg_out_0 				 =>  slv_reg2,

    Interrupt            => IP2Bus_IntrEvent,
                        
	 USB_IFCLK   			=>  USB_IFCLK,  
    USB_SLRD            =>  USB_SLRD,   
    USB_SLWR            =>  USB_SLWR,   
    USB_FLAGA  			=>  USB_FLAGA,  
    USB_FLAGB           =>  USB_FLAGB,  
    USB_FLAGC           =>  USB_FLAGC,  
    USB_FLAGD  			=>  USB_FLAGD,  
    USB_SLOE           =>   USB_SLOE,   
    USB_PKTEND         =>   USB_PKTEND, 
    USB_FIFOADR			=>  USB_FIFOADR,
    USB_FD_T           =>   USB_FD_T,   
    USB_FD_O           =>   USB_FD_O,   
    USB_FD_I				=>  USB_FD_I,	 

    TX_FIFO_Clk       =>  TX_FIFO_Clk,   
    RX_FIFO_Clk       =>  RX_FIFO_Clk,   

    TX_FIFO_DIN      =>  TX_FIFO_DIN_i,   
    TX_FIFO_VLD   	=>  TX_FIFO_VLD_i,   	
    TX_FIFO_RDY	   =>  TX_FIFO_RDY,	

	 RX_FIFO_DOUT  	=>  RX_FIFO_DOUT_i,  
	 RX_FIFO_VLD      =>  RX_FIFO_VLD,   
	 RX_FIFO_RDY		=>  RX_FIFO_RDY_i,	
	  
	 ChipScope				 => ChipScope
	 
);

end IMP;
