-----------------------------------------------------
--
--      Filename: i2c_slave_core.vhd
--      Version:  1.0
--      Author:   Ales Gorkic
--      Company:  KOLT
--      Phone:    +386 (0)31 345993
--      Email:   ales.gorkic@fs.uni-lj.si
--      Change History:
--      Date        Version     Comments
--      08.04.08      0.1       File created
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
--
-- Definition of Ports:
--      RS232_RX                    -- connection to RS232 RX 				
--      RS232_TX                    -- connection to RS232 TX
--      OPT_RX                      -- connection to Optical receiver		
--      OPT_TX                      -- connection to Optical transmitter	
--      LED                         -- physical connection to User LED

--      Sysclk                      -- system clock to MT9V403 (max 66MHz)
--      Lrst_n                      -- reset to MT9V403
--      Frame_sync_n                -- frame_sync_n to MT9V403 (slave only)
--      Pg_n                        -- pg_n to MT9V403 (slave only)
--      Tx_n                        -- tx_n to MT9V403 (slave only)
--      Resmem                      -- resmem to MT9V403 (slave only)
--      Expose                      -- exposition time from MT9V403					
--      Row_valid                   -- row valid from MT9V403
--      Frame_valid                 -- frame valid from MT9V403
--      Data                        -- data from MT9V403
--      Sclk                        -- serial clock output to MT9V403
--      Sdata_I                     -- serial data input from slave
--      Sdata_O                     -- serial data output to slave
--      Sdata_T                     -- serial data output enable (active low)
--
--      Interrupt                   -- Interrupt output to PPC or INTC
--
--      FX_Clk                      -- Fast clock (66MHz) for synthesis to Sysclk
--
--      SYS_Clk                     -- OPB clock
--      SYS_Rst                     -- OPB bus reset        
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Libraries
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library xps_i2c_slave_v1_20_a;
use xps_i2c_slave_v1_20_a.all;

entity i2c_slave_core is
	generic(
    C_I2C_ADDRESS        : integer := 63;
	 C_MB_INT_BYTES       : integer := 12 --number of bytes received to trigger interrupt
	);
   Port (     
    SYS_Clk              : in  std_logic;
    SYS_Rst              : in  std_logic;

	 Reg_in_0 				 : in std_logic_vector(0 to 31);
	 Reg_in_1 				 : in std_logic_vector(0 to 31);
	 Reg_in_2 				 : in std_logic_vector(0 to 31);
	 Reg_out_0 				 : out std_logic_vector(0 to 31);
	 Reg_out_1 				 : out std_logic_vector(0 to 31);
	 Reg_out_2 				 : out std_logic_vector(0 to 31);
	 
    Interrupt            : out std_logic; --Microblaze interrupt
	 
	 USB_IFCLK            : in  std_logic;

	 USB_INT_in           : in std_logic; --interrupt to master
	 USB_INT              : out std_logic; --interrupt to master
	 
    USB_SCL          	 : in std_logic; --I2C clock
    USB_SDA_I      		 : in std_logic; --I2C data input
    USB_SDA_O      		 : out std_logic; --I2C data output
    USB_SDA_T      		 : out std_logic; --I2C data toggle
	 
	 ChipScope		       : out std_logic_vector(31 downto 0) := (others => '0')
	 );
end i2c_slave_core;

architecture Behavioral of i2c_slave_core is

------------------------------------------
-- Component declaration
------------------------------------------

------------------------------------------
-- Signals declaration
------------------------------------------

  -- I2C SLAVE-INTERFACE-SIGNALE
   signal Reset_n          : std_logic := '0';
   signal slv_tx_data    : std_logic_vector(7 downto 0);
   signal slv_rx_data    : std_logic_vector(7 downto 0);
   signal slv_rx_vld     : std_logic;
   signal slv_rx_vld_r   : std_logic;
   signal slv_rx_ack     : std_logic;
   signal slv_tx_wr      : std_logic;
   signal slv_tx_empty   : std_logic;
   signal slv_busy       : std_logic;
   signal i2c_byte_cnt : integer := 0;
   signal i2c_recv_int       : std_logic := '0';	--trigger interrupt if received i2c data
   signal i2c_send_int       : std_logic := '0';	--trigger interrupt to request i2c data send

  signal USB_SDA_O_i               : std_logic;
  signal USB_SDA_T_i               : std_logic;

begin

------------------------------------------
-- Signal connections
------------------------------------------           

	Reset_n <= not SYS_Rst;

	Interrupt <= i2c_recv_int;

   USB_SDA_O   <= USB_SDA_O_i;
   USB_SDA_T   <= USB_SDA_T_i;

	ChipScope <= slv_rx_data & slv_tx_data
						& "00000" & USB_INT_in & i2c_send_int & i2c_recv_int
						& slv_rx_vld & slv_rx_ack & slv_tx_wr & slv_tx_empty
						& USB_SDA_I & USB_SDA_O_i & USB_SDA_T_i & USB_SCL;


------------------------------------------
-- Processes
------------------------------------------
REGISTER_USB_INT_PROCESS : process (USB_IFCLK)
begin
	if (USB_IFCLK'event and USB_IFCLK = '1') then --rising edge
		USB_INT <= i2c_send_int;
	end if;
end process REGISTER_USB_INT_PROCESS;

REGISTERS_RW_PROCESS : process (SYS_Clk)
begin
	if (SYS_Clk'event and SYS_Clk = '1') then --rising edge
		slv_rx_ack <= '0'; --no ack
		slv_tx_wr <= '0'; --no write
		slv_rx_vld_r <= slv_rx_vld; --register
		if (USB_INT_in = '1') then
			i2c_send_int <= '1';
		end if;
		if (SYS_Rst = '1' or slv_busy = '0') then --reset
			i2c_byte_cnt <= 0;
			i2c_recv_int <= '0'; --no int
		elsif (slv_rx_vld_r < slv_rx_vld) then --MB 	registers write access granted
			i2c_byte_cnt <= i2c_byte_cnt+1; --increment byte counter
			slv_rx_ack <= '1'; --ack
			if (i2c_byte_cnt = (C_MB_INT_BYTES-1)) then
				i2c_recv_int <= '1'; --trigger int
			end if;
			if (i2c_byte_cnt < 4) then
				Reg_out_0(i2c_byte_cnt*8 to (i2c_byte_cnt+1)*8-1) <= slv_rx_data; --write REG0 data
			elsif (i2c_byte_cnt < 8) then
				Reg_out_1((i2c_byte_cnt-4)*8 to (i2c_byte_cnt-3)*8-1) <= slv_rx_data; --write REG1 data
			elsif (i2c_byte_cnt < 12) then
				Reg_out_2((i2c_byte_cnt-8)*8 to (i2c_byte_cnt-7)*8-1) <= slv_rx_data; --write REG2 data
			end if;
		elsif (slv_tx_empty = '1' and slv_tx_wr = '0') then --i2c buffer is empty send data
			i2c_send_int <= '0'; --clear interrupt
			i2c_byte_cnt <= i2c_byte_cnt+1; --increment byte counter
			slv_tx_wr <= '1'; --write
			if (i2c_byte_cnt < 4) then
				slv_tx_data <= Reg_in_0(i2c_byte_cnt*8 to (i2c_byte_cnt+1)*8-1); --read REG0 data
			elsif (i2c_byte_cnt < 8) then
				slv_tx_data <= Reg_in_1((i2c_byte_cnt-4)*8 to (i2c_byte_cnt-3)*8-1); --read REG1 data
			elsif (i2c_byte_cnt < 12) then
				slv_tx_data <= Reg_in_2((i2c_byte_cnt-8)*8 to (i2c_byte_cnt-7)*8-1); --read REG2 data
			end if;
		end if;
  end if;
end process REGISTERS_RW_PROCESS;


------------------------------------------
-- Port Maps
------------------------------------------

I2C_SLAVE_INSTANCE : entity xps_i2c_slave_v1_20_a.i2c_slave
	   generic map
      (
         SDA_DELAY => 5
      )
	   port map
      (
         clk            => SYS_Clk,
         Reset_n        => Reset_n,
         scl            => USB_SCL,
         sda_I          => USB_SDA_I,
         sda_O          => USB_SDA_O_i,
         sda_T          => USB_SDA_T_i,
         slv_adr        => C_I2C_ADDRESS,
         sniffer_on     => false,
         tx_data        => slv_tx_data,
         tx_wr          => slv_tx_wr,
         tx_empty       => slv_tx_empty, 
         rx_data        => slv_rx_data,
         rx_vld         => slv_rx_vld,
         rx_ack         => slv_rx_ack,
         busy           => slv_busy
        -- error          => slv_error
      );

end Behavioral;

