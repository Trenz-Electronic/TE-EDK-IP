-----------------------------------------------------
--
--      Filename: mfx2_core.vhd
--      Version:  0.3
--      Author:   Ales Gorkic
--      Company:  KOLT
--      Phone:    031 345993
--      Email:   ales.gorkic@fs.uni-lj.si
--      Change History:
--      Date        Version     Comments
--      07.04.06      0.3       The OPB Master, FIFO and Frontend work !
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
--      C_OPB_AWIDTH                -- OPB address bus width
--      C_OPB_DWIDTH                -- OPB data bus width
--      C_SOPB_BASEADDR             -- SOPB base address
--      C_SOPB_HIGHADDR              -- SOPB high address
--
-- Definition of Ports:
--      Interrupt                   -- Interrupt output to MB or INTC
--
--      SYS_Clk                    -- Slave OPB clock
--      SOPB_Rst                    -- Slave OPB bus reset        
--      SOPB_ABus                   -- Slave OPB address bus        
--      SOPB_BE                     -- Slave OPB error acknowledge
--      SOPB_DBus                   -- Slave OPB data bus
--      SOPB_RNW                    -- Slave OPB timeout
--      SOPB_select                 -- Slave OPB select
--      SOPB_seqAddr                -- Slave OPB sequential address
--      Sl_DBus                     -- Slave OPB data bus
--      Sl_errAck                   -- Slave OPB error acknowledge
--      Sl_retry                    -- Slave OPB retry
--      Sl_toutSup                  -- Slave OPB timeout supression
--      Sl_xferAck                  -- Slave OPB xferack
--
--
--      USB_IFCLK                   -- FX2 IF clock (48MHz)
--      USB_SLRD                    -- read from FX2 fifo en (not used)
--      USB_SLWR                    -- write to FX2 fifo en 
--      USB_FLAGA                   -- FX2 fifo status programable full flag
--      USB_FLAGB                   -- FX2 fifo status full flag
--      USB_FLAGC                   -- FX2 fifo status empty flag
--      USB_PA_T                    -- FX2 port A tristate toggle (1= FPGA read)
--      USB_PA_O                    -- FX2 port A output
--      USB_PA_I                    -- FX2 port A input
--      USB_FD_T                    -- FX2 Data port tristate toggle (1= FPGA read)
--      USB_FD_O                    -- FX2 Data port output
--      USB_FD_I                    -- FX2 Data port input
--
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

Library XilinxCoreLib;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;
--use work.proc_common_pkg.all;
library xps_fx2_v1_50_a;
use xps_fx2_v1_50_a.fx2_engine;

-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity fx2_core is
  generic (
    C_TX_FIFO_KBYTE         : integer := 32;
    C_RX_FIFO_KBYTE         : integer := 0;
		C_USE_ADDR_FIFO         : integer := 0;
		C_TX_RDY_ALMOST_FULL 		: integer := 1;
		C_TX_FIFO_CLK_180       : integer := 0;
		C_USE_CRITICAL					: integer := 0
    );
  port (
    SYS_Clk              : in  std_logic;
    SYS_Rst              : in  std_logic;

	 Reg_in_0 				 : in std_logic_vector(0 to 31);
	 Reg_in_1 				 : in std_logic_vector(0 to 31);
	 Reg_out_0 				 : out std_logic_vector(0 to 31);

    Interrupt            : out std_logic_VECTOR(0 to 7);
	USB_RX_CLK							: in  std_logic;
    USB_IFCLK            : in  std_logic;
    USB_SLRD             : out std_logic;
    USB_SLWR             : out std_logic;
    USB_FLAGA            : in std_logic;
    USB_FLAGB            : in std_logic;
    USB_FLAGC            : in std_logic;
		USB_FLAGD            : in std_logic;
		USB_SLOE             : out std_logic;
		USB_PKTEND           : out std_logic;
		USB_FIFOADR          : out std_logic_vector(1 downto 0); --"00"=EP2,"01"=EP4,"10"=EP6,11"=EP8
    USB_FD_T             : out std_logic_vector(7 downto 0) := (others => '1'); 
    USB_FD_O             : out std_logic_vector(7 downto 0) := (others => '0');
    USB_FD_I             : in std_logic_vector(7 downto 0);

    TX_FIFO_Clk           : in std_logic := '0';
    RX_FIFO_Clk           : in std_logic := '0';

    TX_FIFO_DIN           : in std_logic_vector(0 to 31) := (others => '0');
    TX_FIFO_VLD           : in std_logic := '0';
		TX_FIFO_RDY						: out std_logic := '0';

    RX_FIFO_DOUT          : out std_logic_vector(0 to 31) := (others => '0');
		RX_FIFO_VLD           : out	std_logic := '0';
    RX_FIFO_RDY						:	in	std_logic := '0';
	                    
    ChipScope        			: out std_logic_vector(0 to 31) := (others => '0')
    );

end entity fx2_core;

------------------------------------------------------------------------------
-- Architecture section
------------------------------------------------------------------------------

architecture IMP of fx2_core is

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
constant TX_FIFO_COUNT_BITS      : integer := 8 + log2(C_TX_FIFO_KBYTE);
constant RX_FIFO_COUNT_BITS      : integer := 9 + log2(C_RX_FIFO_KBYTE);
------------------------------------------
-- Component declaration
------------------------------------------

component tx_fifo
	port (
	din: IN std_logic_VECTOR(31 downto 0);
	rd_clk: IN std_logic;
	rd_en: IN std_logic;
	rst: IN std_logic;
	wr_clk: IN std_logic;
	wr_en: IN std_logic;
	dout: OUT std_logic_VECTOR(7 downto 0);
	empty: OUT std_logic;
	full: OUT std_logic;
	--almost_full: OUT std_logic;	-- In repository but not in reference
	overflow: OUT std_logic;
	valid: OUT std_logic;
	underflow: OUT std_logic;
	wr_data_count: OUT std_logic_VECTOR(TX_FIFO_COUNT_BITS-1 downto 0));
end component;

component tx_addr_fifo IS
	port (
	din: IN std_logic_VECTOR(1 downto 0);
	rd_clk: IN std_logic;
	rd_en: IN std_logic;
	rst: IN std_logic;
	wr_clk: IN std_logic;
	wr_en: IN std_logic;
	dout: OUT std_logic_VECTOR(1 downto 0);
	empty: OUT std_logic;
	full: OUT std_logic);
end component;

component rx_fifo
	port (
	din: IN std_logic_VECTOR(7 downto 0);
	rd_clk: IN std_logic;
	rd_en: IN std_logic;
	rst: IN std_logic;
	wr_clk: IN std_logic;
	wr_en: IN std_logic;
	almost_full: OUT std_logic;
	dout: OUT std_logic_VECTOR(31 downto 0);
	empty: OUT std_logic;
	full: OUT std_logic;
	overflow: OUT std_logic;
	valid: OUT std_logic;
	rd_data_count: OUT std_logic_VECTOR(RX_FIFO_COUNT_BITS-1 downto 0);
	underflow: OUT std_logic);
end component;

component fx2_engine is
	generic (
		TX_FIFO_COUNT_BITS			: integer := 13;
		RX_FIFO_COUNT_BITS			: integer := 9;
		C_TX_FIFO_KBYTE         : integer := 32;
    C_RX_FIFO_KBYTE         : integer := 0;
		C_USE_ADDR_FIFO         : integer := 0;
		C_TX_RDY_ALMOST_FULL 		: integer := 1;
		C_TX_FIFO_CLK_180       : integer := 0
		--C_USE_CRITICAL					: integer := 0
	);
  port (
    SYS_Clk              		: in  std_logic;
    SYS_Rst              		: in  std_logic;

		Reg_in_0 				 				: in  std_logic_vector(0 to 31);
		Reg_in_1 				 				: in  std_logic_vector(0 to 31);
		Reg_out_0 				 			: out std_logic_vector(0 to 31);

    Interrupt            		: out std_logic_VECTOR(0 to 7);

	USB_RX_CLK							: in  std_logic;
    USB_IFCLK            		: in  std_logic;
    USB_SLRD             		: out std_logic;
    USB_SLWR             		: out std_logic;
    USB_FLAGA            		: in  std_logic;	-- Not used
    USB_FLAGB            		: in  std_logic;
    USB_FLAGC            		: in  std_logic;
		USB_FLAGD            		: in  std_logic;
		USB_SLOE             		: out std_logic;
		USB_PKTEND           		: out std_logic;
		USB_FIFOADR         		: out std_logic_vector(1 downto 0); --"00"=EP2,"01"=EP4,"10"=EP6,11"=EP8
    USB_FD_T             		: out std_logic_vector(7 downto 0) := (others => '1'); --OE active low
    USB_FD_O             		: out std_logic_vector(7 downto 0) := (others => '0');
    USB_FD_I             		: in  std_logic_vector(7 downto 0);
		
		tx_fifo_rd								: out std_logic;
		tx_fifo_data							: in  std_logic_vector(7 downto 0);
		tx_fifo_reset							: out std_logic;
		tx_fifo_full							: in  std_logic;
		tx_fifo_empty							: in	std_logic;
		tx_fifo_overflow					: in  std_logic;
		tx_fifo_count							: in	std_logic_vector(TX_FIFO_COUNT_BITS-1 downto 0);
		tx_fifo_valid						: in std_logic;
		
		tx_fifo_rdy								: out std_logic;
		
		tx_addr_fifo_rd						: out std_logic;
		tx_addr_fifo_data					: in  std_logic_vector(1 downto 0);
		tx_addr_fifo_reset				: out std_logic;

		rx_fifo_wr								: out	std_logic;
		rx_fifo_data							: out	std_logic_vector(7 downto 0);
		rx_fifo_reset							: out std_logic;
		rx_fifo_full							: in  std_logic;
		rx_fifo_empty							: in	std_logic;
		rx_fifo_almostfull				: in  std_logic;
		rx_fifo_underflow					: in  std_logic;
		rx_fifo_count							: in	std_logic_vector(RX_FIFO_COUNT_BITS-1 downto 0);
	                    
    ChipScope        					: out std_logic_vector(0 to 31) := (others => '0')
    );
end component;

------------------------------------------
-- Signals declaration
------------------------------------------
signal tx_fifo_rd									: std_logic;
signal tx_fifo_data								: std_logic_vector(7 downto 0);
signal tx_fifo_reset							: std_logic;
signal tx_fifo_full								: std_logic;
signal tx_fifo_empty							: std_logic;
signal tx_fifo_overflow						: std_logic;
signal tx_fifo_count							: std_logic_vector(TX_FIFO_COUNT_BITS-1 downto 0);
signal tx_fifo_valid						: std_logic;
		
signal tx_addr_fifo_rd						: std_logic;
signal tx_addr_fifo_data					: std_logic_vector(1 downto 0);
signal tx_addr_fifo_reset					: std_logic;

signal rx_fifo_wr									: std_logic;
signal rx_fifo_data								: std_logic_vector(7 downto 0);
signal rx_fifo_reset							: std_logic;
signal rx_fifo_full								: std_logic;
signal rx_fifo_empty							: std_logic;
signal rx_fifo_almostfull					: std_logic;
signal rx_fifo_underflow					: std_logic;
signal rx_fifo_count							: std_logic_vector(RX_FIFO_COUNT_BITS-1 downto 0);

-- Blackbox attr: tx_fifo rx_fifo tx_addr_fifo
attribute BOX_TYPE : string;
attribute BOX_TYPE of tx_fifo : component is "BLACK_BOX";

------------------------------------------
-- Implementation
------------------------------------------
begin
------------------------------------------
-- Signal connections
------------------------------------------

--------------------------------------------
---- Port Maps
--------------------------------------------
fx2_eng: fx2_engine
	generic map(
		TX_FIFO_COUNT_BITS			=> TX_FIFO_COUNT_BITS,
		RX_FIFO_COUNT_BITS			=> RX_FIFO_COUNT_BITS,
		C_TX_FIFO_KBYTE         => C_TX_FIFO_KBYTE,
    C_RX_FIFO_KBYTE         => C_RX_FIFO_KBYTE,
		C_USE_ADDR_FIFO         => C_USE_ADDR_FIFO,
		C_TX_RDY_ALMOST_FULL 		=> C_TX_RDY_ALMOST_FULL,
		C_TX_FIFO_CLK_180       => C_TX_FIFO_CLK_180
		--C_USE_CRITICAL					=> C_USE_CRITICAL
	)
  port map(
    SYS_Clk              		=> SYS_Clk,
    SYS_Rst              		=> SYS_Rst,

		Reg_in_0 				 				=> Reg_in_0,
		Reg_in_1 				 				=> Reg_in_1,
		Reg_out_0 				 			=> Reg_out_0,

    Interrupt            		=> Interrupt,
	USB_RX_CLK	=> USB_RX_CLK,
    USB_IFCLK            		=> USB_IFCLK,
    USB_SLRD             		=> USB_SLRD,
    USB_SLWR             		=> USB_SLWR,
    USB_FLAGA            		=> USB_FLAGA,
    USB_FLAGB            		=> USB_FLAGB,
    USB_FLAGC            		=> USB_FLAGC,
		USB_FLAGD            		=> USB_FLAGD,
		USB_SLOE             		=> USB_SLOE,
		USB_PKTEND           		=> USB_PKTEND,
		USB_FIFOADR         		=> USB_FIFOADR,
    USB_FD_T             		=> USB_FD_T,
    USB_FD_O             		=> USB_FD_O,
    USB_FD_I             		=> USB_FD_I,
		
		tx_fifo_rd							=> tx_fifo_rd,
		tx_fifo_data						=> tx_fifo_data,
		tx_fifo_reset						=> tx_fifo_reset,
		tx_fifo_full						=> tx_fifo_full,
		tx_fifo_empty						=> tx_fifo_empty,
		tx_fifo_overflow				=> tx_fifo_overflow,
		tx_fifo_count						=> tx_fifo_count,
		tx_fifo_rdy							=> TX_FIFO_RDY,
		tx_fifo_valid					=> tx_fifo_valid,
		
		tx_addr_fifo_rd					=> tx_addr_fifo_rd,
		tx_addr_fifo_data				=> tx_addr_fifo_data,
		tx_addr_fifo_reset			=> tx_addr_fifo_reset,

		rx_fifo_wr							=> rx_fifo_wr,
		rx_fifo_data						=> rx_fifo_data,
		rx_fifo_reset						=> rx_fifo_reset,
		rx_fifo_full						=> rx_fifo_full,
		rx_fifo_empty						=> rx_fifo_empty,
		rx_fifo_almostfull			=> rx_fifo_almostfull,
		rx_fifo_underflow				=> rx_fifo_underflow,
		rx_fifo_count						=> rx_fifo_count,
	                    
    ChipScope        				=> ChipScope
    );


TX_FIFI : tx_fifo
	port map(
    din						=> TX_FIFO_DIN,
    rd_clk				=> USB_IFCLK,
    rd_en					=> tx_fifo_rd,
    rst						=> tx_fifo_reset,
    wr_clk				=> TX_FIFO_Clk,
    wr_en					=> TX_FIFO_VLD,
    dout					=> tx_fifo_data,
    empty					=> tx_fifo_empty,
    full					=> tx_fifo_full,
    overflow			=> tx_fifo_overflow,
		valid					=> tx_fifo_valid,
		underflow			=> open,
		wr_data_count	=> tx_fifo_count
	);

--REG_FIFOADR <= Reg_in_0(26 to 27);	--signal to select EP addr

TX_FIFI_ADDR_GEN : 
if C_USE_ADDR_FIFO=1
generate
	begin 
	TX_FIFI_ADDR : tx_addr_fifo
		port map (
			din 		=> Reg_in_0(26 to 27),
			rd_clk 	=> USB_IFCLK,
			rd_en 	=> tx_addr_fifo_rd,
			rst 		=> tx_addr_fifo_reset,
			wr_clk 	=> TX_FIFO_Clk,
			wr_en 	=> TX_FIFO_VLD,
			dout 		=> tx_addr_fifo_data,
			empty 	=> open,
			full 		=> open
			);
end generate;

RX_FIFO_GEN : 
if C_RX_FIFO_KBYTE>0
generate
	begin 
	RX_FIFI : rx_fifo
		port map (
			din 					=> rx_fifo_data,
			rd_clk 				=> RX_FIFO_Clk,
			rd_en 				=> RX_FIFO_RDY,
			rst 					=> rx_fifo_reset,
			wr_clk 				=> USB_IFCLK,
			wr_en 				=> rx_fifo_wr,
			almost_full 	=> rx_fifo_almostfull,
			dout 					=> RX_FIFO_DOUT,
			empty 				=> rx_fifo_empty,
			full 					=> rx_fifo_full,
			overflow 			=> open,
			valid 				=> RX_FIFO_VLD,
			rd_data_count	=> rx_fifo_count,
			underflow 		=> rx_fifo_underflow
			);
end generate;
--------------------------------------------

end IMP;
