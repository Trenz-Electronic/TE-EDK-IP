-------------------------------------------------------------------------------
--  XPS Serial Peripheral Interface Module - entity/architecture pair
-------------------------------------------------------------------------------
--
-- ************************************************************************
-- ** DISCLAIMER OF LIABILITY                                            **
-- **                                                                    **
-- ** This file contains proprietary and confidential information of     **
-- ** Xilinx, Inc. ("Xilinx"), that is distributed under a license       **
-- ** from Xilinx, and may be used, copied and/or disclosed only         **
-- ** pursuant to the terms of a valid license agreement with Xilinx.    **
-- **                                                                    **
-- ** XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION              **
-- ** ("MATERIALS") "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER         **
-- ** EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                **
-- ** LIMITATION, ANY WARRANTY WITH RESPECT TO NONINFRINGEMENT,          **
-- ** MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx      **
-- ** does not warrant that functions included in the Materials will     **
-- ** meet the requirements of Licensee, or that the operation of the    **
-- ** Materials will be uninterrupted or error-free, or that defects     **
-- ** in the Materials will be corrected. Furthermore, Xilinx does       **
-- ** not warrant or make any representations regarding use, or the      **
-- ** results of the use, of the Materials in terms of correctness,      **
-- ** accuracy, reliability or otherwise.                                **
-- **                                                                    **
-- ** Xilinx products are not designed or intended to be fail-safe,      **
-- ** or for use in any application requiring fail-safe performance,     **
-- ** such as life-support or safety devices or systems, Class III       **
-- ** medical devices, nuclear facilities, applications related to       **
-- ** the deployment of airbags, or any other applications that could    **
-- ** lead to death, personal injury or severe property or               **
-- ** environmental damage (individually and collectively, "critical     **
-- ** applications"). Customer assumes the sole risk and liability       **
-- ** of any use of Xilinx products in critical applications,            **
-- ** subject only to applicable laws and regulations governing          **
-- ** limitations on product liability.                                  **
-- **                                                                    **
-- ** Copyright 2005, 2006, 2008, 2009, 2010 Xilinx, Inc.                **
-- ** All rights reserved.                                               **
-- **                                                                    **
-- ** This disclaimer and copyright notice must be retained as part      **
-- ** of this file at all times.                                         **
-- ************************************************************************
--
-------------------------------------------------------------------------------
-- Filename:        xps_spi.vhd
-- Version:         v2.02.a
-- Description:     Serial Peripheral Interface (SPI) Module for interfacing
--                  with a 32-bit PLBv46 Bus.
--
-------------------------------------------------------------------------------
-- Structure:   This section shows the hierarchical structure of xps_spi.
--
--              xps_spi.vhd
--                 --plbv46_slave_single.vhd
--                    --plb_slave_attachment.vhd
--                       --plb_address_decoder.vhd
--                 --interrupt_control.vhd
--                 --soft_reset.vhd
--                 --srl_fifo.vhd
--                 --spi_receive_transmit_reg.vhd
--                 --spi_cntrl_reg.vhd
--                 --spi_status_slave_sel_reg.vhd
--                 --spi_module.vhd
--                 --spi_fifo_ifmodule.vhd
--                 --spi_occupancy_reg.vhd
-------------------------------------------------------------------------------
-- Author:      MZC
--
-- History:
--
--  MZC      1/15/08      -- First version
-- ~~~~~~
--  - Redesigned version of xps_spi. Based on xps spi v1.00a
-- ^^^^^^
--  SK       2/04/08
-- ~~~~~~
--  Optimized the design. combined the files for receiver and x'mitter section
--  into one file. These files were separate earlier.
--  Also combined the status register and slave select register files.
--  These files were separate earlier.
--  Also removed the local ACK's generated in each file and replaced the logic
--  at the top level file by a simple logic
--  removed unwanted signals and code cleaning.
-- ^^^^^^
--  SK       04/03/08
-- ~~~~~~
-- -- Created new version of the core. i.e. v2_00_b
-- ^^^^^^
--  SK       03/11/08
-- ~~~~~~
-- -- Update the version of the core(v2_01_a) based upon v2_00_b version.
-- -- IPIF and proc_common libraries are upgraded.
-- ^^^^^^
--  SK       05/16/09
-- ~~~~~~
-- -- Registered the SCK output in C_SCK_RATIO = 4 mode.
-- -- CR 512141 is closed.
-- ^^^^^^
--  SK       02/18/10
-- ~~~~~~
-- 1. Added interrupt logic when the SPI is configured in the slave mode.
--    Interrupt will be generated when the SPISEL line is asserted.
-- 2. Added DRR FIFO not empty interrupt. As soon as single data is received DRR
--    FIFO can generate an interrupt based upon IPIER setting. Applicable only
--    in slave mode when FIFO is present.
-- 3. CR 543500 is closed.
-- ^^^^^^
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x"
--      reset signals:                          "rst", "rst_n"
--      generics:                               "C_*"
--      user defined types:                     "*_TYPE"
--      state machine next state:               "*_ns"
--      state machine current state:            "*_cs"
--      combinatorial signals:                  "*_cmb"
--      pipelined or register delay signals:    "*_d#"
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce"
--      internal version of output port         "*_i"
--      device pins:                            "*_pin"
--      ports:                                  - Names begin with Uppercase
--      processes:                              "*_PROCESS"
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_misc.or_reduce;
use IEEE.std_logic_misc.and_reduce;


-------------------------------------------------------------------------------
-- proc common library is used for different function declarations
-------------------------------------------------------------------------------
library proc_common_v3_00_a;
use proc_common_v3_00_a.ipif_pkg.SLV64_ARRAY_TYPE;
use proc_common_v3_00_a.ipif_pkg.INTEGER_ARRAY_TYPE;
use proc_common_v3_00_a.ipif_pkg.calc_num_ce;
use proc_common_v3_00_a.ipif_pkg.INTR_REG_EVENT;
use proc_common_v3_00_a.proc_common_pkg.RESET_ACTIVE;


library plbv46_slave_single_v1_01_a;

library interrupt_control_v2_01_a;

library xps_spi_v2_02_a;

-------------------------------------------------------------------------------
--                     Definition of Generics
-------------------------------------------------------------------------------
-- SPI generics
--  C_FIFO_EXIST          --    non-zero if FIFOs exist
--  C_SCK_RATIO           --    2, 4, 16, 32, , , , 1024, 2048 SPI Clock
--                        --    ratios
--  C_NUM_SS_BITS         --    Total number of SS-bits
--  C_NUM_TRANSFER_BITS   --    SPI Serial transfer width.
--                        --    Can be 8, 16 or 32 bit wide
--
-- PLBv46 Slave Single block generics
--  C_FAMILY              -- FPGA Family for which the serial
--                        -- peripheral interface is targeted
--  C_BASEADDR            -- Vector of length C_SPLB_AWIDTH
--  C_HIGHADDR            -- Permits alias of address space
--                        -- by making greater than x7F
--  C_SPPB_AWIDTH         -- Width of SPLB Address Bus (in bits)
--  C_SPLB_DWIDTH         -- Width of the SPPB Data Bus (in bits)
--  C_SPLB_P2P            -- Selects point-to-point bus topology
--  C_SPLB_MID_WIDTH      -- PLB Master ID Bus width
--  C_SPLB_NUM_MASTERS    -- Number of PLB Masters
--  C_SPLB_SUPPORT_BURSTS -- Enables burst mode of operation
--  C_SPLB_NATIVE_DWIDTH  -- Width of the slave data bus
--                        -- only orinternal and external both

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--                  Definition of Ports
-------------------------------------------------------------------------------

-- SYSTEM SIGNALS
--  SPLB_Clk                 --    SPLB Clock
--  SPLB_Rst                 --    Reset Signal

-- SPI INTERFACE
--  SCK_I                    --    SPI Bus Clock Input
--  SCK_O                    --    SPI Bus Clock Output
--  SCK_T                    --    SPI Bus Clock 3-state Enable
--                                 (3-state when high)
--  MISO_I                   --    Master out,Slave in Input
--  MISO_O                   --    Master out,Slave in Output
--  MISO_T                   --    Master out,Slave in 3-state Enable
--  MOSI_I                   --    Master in,Slave out Input
--  MOSI_O                   --    Master in,Slave out Output
--  MOSI_T                   --    Master in,Slave out 3-state Enable
--  SPISEL                   --    Local SPI slave select active low input
--                                 has to be initialzed to VCC
--  SS_I                     --    Input of slave select vector
--                                 of length N input where there are
--                                 N SPI devices,but not connected
--  SS_O                     --    One-hot encoded,active low slave select
--                                 vector of length N ouput
--  SS_T                     --    Single 3-state control signal for
--                                 slave select vector of length N
--                                 (3-state when high)

-- PLBv46 SlAVE SINGLE INTERFACE
-- Bus slave signals
--  PLB_ABus                 --    Each master is required to provide a valid
--                                 32-bit address when its request signal is
--                                 asserted. The PLB will then arbitrate the
--                                 requests and allow the highest priority
--                                 master’s address to be gated onto the
--                                 PLB_ABus
--  PLB_PAValid              --    This signal is asserted by the PLB arbiter
--                                 in response to the assertion of Mn_request
--                                 and to indicate that there is a valid
--                                 primary address and transfer qualifiers on
--                                 the PLB outputs
--  PLB_masterID             --    These signals indicate to the slaves the
--                                 identification of the master of the current
--                                 transfer
--  PLB_RNW                  --    This signal is driven by the master and is
--                                 used to indicate whether the request is for
--                                 a read or a write transfer
--  PLB_BE                   --    These signals are driven by the master. For
--                                 a non-line and non-burst transfer they
--                                 identify which bytes of the target being
--                                 addressed are to be read from or written to.
--                                 Each bit corresponds to a byte lane on the
--                                 read or write data bus
--  PLB_size                 --    The PLB_size(0:3) signals are driven by the
--                                 master to indicate the size of the requested
--                                 transfer.
--  PLB_type                 --    The Mn_type signals are driven by the master
--                                 and are used to indicate to the slave,via
--                                 the PLB_type signals, the type of transfer
--                                 being requested
--  PLB_wrDBus               --    This data bus is used to transfer data
--                                 between a master and a slave during a PLB
--                                 write transfer
-- Slave response signals
--  Sl_addrAck               --    This signal is asserted to indicate that the
--                                 slave has acknowledged the address and will
--                                 latch the address
--  Sl_SSize                 --    The Sl_SSize(0:1) signals are outputs of all
--                                 non 32-bit PLB slaves. These signals are
--                                 activated by the slave with the assertion of
--                                 PLB_PAValid or SAValid and a valid slave
--                                 address decode and must remain negated at
--                                 all other times.
--  Sl_wait                  --    This signal is asserted to indicate that the
--                                 slave has recognized the PLB address as a
--                                 valid address
--  Sl_rearbitrate           --    This signal is asserted to indicate that the
--                                 slave is unable to perform the currently
--                                 requested transfer and require the PLB
--                                 arbiter to re-arbitrate the bus
--  Sl_wrDAck                --    This signal is driven by the slave for a
--                                 write transfer to indicate that the data
--                                 currently on the PLB_wrDBus bus is no longer
--                                 required by the slave i.e. data is latched
--  Sl_wrComp                --    This signal is asserted by the slave to
--                                 indicate the end of the current write
--                                 transfer
--  Sl_rdDBus                --    Slave read bus
--  Sl_rdDAck                --    This signal is driven by the slave to
--                                 indicate that the data on the Sl_rdDBus bus
--                                 is valid and must be latched at the end of
--                                 the current clock cycle
--  Sl_rdComp                --    This signal is driven by the slave and is
--                                 used to indicate to the PLB arbiter that the
--                                 read transfer is either complete, or will be
--                                 complete by the end of the next clock cycle
--  Sl_MBusy                 --    These signals are driven by the slave and
--                                 are used to indicate that the slave is
--                                 either busy performing a read or a write
--                                 transfer, or has a read or write transfer
--                                 pending
--  Sl_MWrErr                --    These signals are driven by the slave and
--                                 are used to indicate that the slave has
--                                 encountered an error during a write transfer
--                                 that was initiated by this master
--  Sl_MRdErr                --    These signals are driven by the slave and
--                                 are used to indicate that the slave has
--                                 encountered an error during a read transfer
--                                 that was initiated by this master

-- INTERRUPT INTERFACE
--  IP2INTC_Irpt             --    Interrupt signal to interrupt controller
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Entity Declaration
-------------------------------------------------------------------------------

entity xps_spi is
 generic
  (
  --SPI generics
    C_FIFO_EXIST         : integer range 0 to 1   := 1;
    C_SCK_RATIO          : integer range 2 to 2048:= 32;
    C_NUM_SS_BITS        : integer range 1 to 32  := 1;
    C_NUM_TRANSFER_BITS  : integer                := 8;

  --PLBv46 slave single block generics
    C_BASEADDR           : std_logic_vector       := X"FFFFFFFF";
    C_HIGHADDR           : std_logic_vector       := X"00000000";
    C_FAMILY             : string                 := "virtex5";
    C_SPLB_AWIDTH        : integer range 32 to 32 := 32;
    C_SPLB_DWIDTH        : integer range 32 to 128:= 32;
    C_SPLB_P2P           : integer range 0 to 1   := 0;
    C_SPLB_MID_WIDTH     : integer range 0 to 4   := 1;
    C_SPLB_NUM_MASTERS   : integer range 1 to 16  := 1;
    C_SPLB_SUPPORT_BURSTS: integer range 0 to 0   := 0;
    C_SPLB_NATIVE_DWIDTH : integer range 32 to 32 := 32
  );
 port
  (
  --SPI INTERFACE
    SCK_I            : in  std_logic;
    SCK_O            : out std_logic;
    SCK_T            : out std_logic;

    MISO_I           : in  std_logic;
    MISO_O           : out std_logic;
    MISO_T           : out std_logic;

    MOSI_I           : in  std_logic;
    MOSI_O           : out std_logic;
    MOSI_T           : out std_logic;

    SPISEL           : in  std_logic;

    SS_I             : in  std_logic_vector(0 to C_NUM_SS_BITS-1);
    SS_O             : out std_logic_vector(0 to C_NUM_SS_BITS-1);
    SS_T             : out std_logic;

  --PLBv46 SLAVE SINGLE INTERFACE
    -- system signals
    SPLB_Clk         : in  std_logic;
    SPLB_Rst         : in  std_logic;
    -- Bus slave signals
    PLB_ABus         : in  std_logic_vector(0 to 31);
    PLB_PAValid      : in  std_logic;
    PLB_masterID     : in  std_logic_vector(0 to C_SPLB_MID_WIDTH-1);
    PLB_RNW          : in  std_logic;
    PLB_BE           : in  std_logic_vector(0 to (C_SPLB_DWIDTH/8) - 1);
    PLB_size         : in  std_logic_vector(0 to 3);
    PLB_type         : in  std_logic_vector(0 to 2);
    PLB_wrDBus       : in  std_logic_vector(0 to C_SPLB_DWIDTH-1);
    --SPI response signals
    Sl_addrAck       : out std_logic;
    Sl_SSize         : out std_logic_vector(0 to 1);
    Sl_wait          : out std_logic;
    Sl_rearbitrate   : out std_logic;
    Sl_wrDAck        : out std_logic;
    Sl_wrComp        : out std_logic;
    Sl_rdDBus        : out std_logic_vector(0 to C_SPLB_DWIDTH-1);
    Sl_rdDAck        : out std_logic;
    Sl_rdComp        : out std_logic;
    Sl_MBusy         : out std_logic_vector(0 to C_SPLB_NUM_MASTERS-1);
    Sl_MWrErr        : out std_logic_vector(0 to C_SPLB_NUM_MASTERS-1);
    Sl_MRdErr        : out std_logic_vector(0 to C_SPLB_NUM_MASTERS-1);

  -- INTERRUPT INTERFACE
    IP2INTC_Irpt     : out std_logic;
  -- Unused Bus slave signals
    PLB_UABus        : in  std_logic_vector(0 to 31);
    PLB_SAValid      : in  std_logic;
    PLB_rdPrim       : in  std_logic;
    PLB_wrPrim       : in  std_logic;
    PLB_abort        : in  std_logic;
    PLB_busLock      : in  std_logic;
    PLB_MSize        : in  std_logic_vector(0 to 1);
    PLB_lockErr      : in  std_logic;
    PLB_wrBurst      : in  std_logic;
    PLB_rdBurst      : in  std_logic;
    PLB_wrPendReq    : in  std_logic;
    PLB_rdPendReq    : in  std_logic;
    PLB_wrPendPri    : in  std_logic_vector(0 to 1);
    PLB_rdPendPri    : in  std_logic_vector(0 to 1);
    PLB_reqPri       : in  std_logic_vector(0 to 1);
    PLB_TAttribute   : in  std_logic_vector(0 to 15);
  -- Unused Slave Response Signals
    Sl_wrBTerm       : out std_logic;
    Sl_rdWdAddr      : out std_logic_vector(0 to 3);
    Sl_rdBTerm       : out std_logic;
    Sl_MIRQ          : out std_logic_vector(0 to C_SPLB_NUM_MASTERS-1)
  );

-------------------------------------------------------------------------------
-- Attributes
-------------------------------------------------------------------------------

      -- Fan-Out attributes for XST

    ATTRIBUTE MAX_FANOUT                   : string;
    ATTRIBUTE MAX_FANOUT   of SPLB_Clk     : signal is "10000";
    ATTRIBUTE MAX_FANOUT   of SPLB_Rst     : signal is "10000";

-----------------------------------------------------------------
  -- Start of PSFUtil MPD attributes
-----------------------------------------------------------------

    ATTRIBUTE ADDR_TYPE   : string;
    ATTRIBUTE ASSIGNMENT  : string;
    ATTRIBUTE HDL         : string;
    ATTRIBUTE IMP_NETLIST : string;
    ATTRIBUTE IP_GROUP    : string;
    ATTRIBUTE IPTYPE      : string;
    ATTRIBUTE MIN_SIZE    : string;
    ATTRIBUTE SIGIS       : string;
    ATTRIBUTE SIM_MODELS  : string;
    ATTRIBUTE STYLE       : string;
-----------------------------------------------------------------
  -- Attribute INITIALVAL added to fix CR 213432
-----------------------------------------------------------------
    ATTRIBUTE INITIALVAL  : string;


    ATTRIBUTE ADDR_TYPE   of  C_BASEADDR   :  constant is  "REGISTER";
    ATTRIBUTE ADDR_TYPE   of  C_HIGHADDR   :  constant is  "REGISTER";
    ATTRIBUTE ASSIGNMENT  of  C_BASEADDR   :  constant is  "REQUIRE";
    ATTRIBUTE ASSIGNMENT  of  C_HIGHADDR   :  constant is  "REQUIRE";
    ATTRIBUTE HDL         of  xps_spi      :  entity   is  "VHDL";
    ATTRIBUTE IMP_NETLIST of  xps_spi      :  entity   is  "TRUE";
    ATTRIBUTE IPTYPE      of  xps_spi      :  entity   is  "PERIPHERAL";

    ATTRIBUTE SIGIS       of  SPLB_Clk     :  signal   is  "CLK";
    ATTRIBUTE SIGIS       of  SPLB_Rst     :  signal   is  "RST";
    ATTRIBUTE SIGIS       of  IP2INTC_Irpt :  signal   is  "INTR_LEVEL_HIGH";
    ATTRIBUTE SIM_MODELS  of  xps_spi      :  entity   is  "BEHAVIORAL";
    ATTRIBUTE STYLE       of  xps_spi      :  entity   is  "HDL";

    ATTRIBUTE INITIALVAL  of  SPISEL       :  signal   is  "VCC";

end xps_spi;

-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------

architecture imp of xps_spi is

-------------------------------------------------------------------------------
-- Function Declarations
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--  Constant Declarations
-------------------------------------------------------------------------------

constant ZEROES               : std_logic_vector(0 to 31) := X"00000000";

--Generics not brought out of top level
constant FIFO_DEPTH           : integer          := 16;
--width of spi shift register
constant C_NUM_BITS_REG       : integer          := 8;
constant C_OCCUPANCY_NUM_BITS : integer          := 4;
constant C_IP_REG_BAR_OFFSET  : std_logic_vector := X"00000060";


constant C_NUM_USER_REGS      : integer := 5 + 2*C_FIFO_EXIST; -- Two
                 -- additional registers are required if FIFOs are optioned in.

constant ARD_ADDR_RANGE_ARRAY : SLV64_ARRAY_TYPE :=
        (
          ZEROES & C_BASEADDR,                 -- interrupt address lower range
          ZEROES & (C_BASEADDR or X"0000003F"),-- interrupt address higher range
          ZEROES & (C_BASEADDR or X"00000040"),-- soft reset register base addr
          ZEROES & (C_BASEADDR or X"00000043"),-- soft reset register high addr
          -- SPI registers Base Address
          ZEROES & (C_BASEADDR or C_IP_REG_BAR_OFFSET),
          -- SPI registers Base Address
          ZEROES & (C_BASEADDR or C_IP_REG_BAR_OFFSET or X"0000001F")
        );

constant ARD_NUM_CE_ARRAY     : INTEGER_ARRAY_TYPE :=
        (
          0 => 16    ,             -- 16  CEs required for interrupt
          1 => 1,                  -- 1   CE  required for soft reset
          2 => C_NUM_USER_REGS
        );

constant IP_INTR_MODE_ARRAY : INTEGER_ARRAY_TYPE(0 to (8))  :=
    (
      others => INTR_REG_EVENT
      -- Seven  interrupts if C_FIFO_EXIST = 0
      -- OR
      -- Eight interrupts if C_FIFO_EXIST = 0 and slave mode
      ----------------------- OR ---------------------------
      -- Nine  interrupts if C_FIFO_EXIST = 1 and slave mode
      -- OR
      -- Seven  interrupts if C_FIFO_EXIST = 1
    );

-- These constants are indices into the "CE" arrays for the various registers.
constant INTR_LO  : natural :=  0;
constant INTR_HI  : natural := 15;
constant SWRESET  : natural := 16;
constant SPICR    : natural := 17;
constant SPISR    : natural := 18;
constant SPIDTR   : natural := 19;
constant SPIDRR   : natural := 20;
constant SPISSR   : natural := 21;
constant SPITFOR  : natural := 22;
constant SPIRFOR  : natural := 23;

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

--SPI MODULE SIGNALS
signal spiXfer_done_int       : std_logic;
signal dtr_underrun_int       : std_logic;
signal modf_strobe_int        : std_logic;
signal slave_MODF_strobe_int  : std_logic;

--OR REGISTER/FIFO SIGNALS
--TO/FROM REG/FIFO DATA
signal receive_Data_int       : std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);
signal transmit_Data_int      : std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);
--Extra bit required for signal Register_Data_ctrl
signal register_Data_cntrl_int  : std_logic_vector(0 to C_NUM_BITS_REG+1);
signal register_Data_slvsel_int : std_logic_vector(0 to C_NUM_SS_BITS-1);
signal reg2SA_Data_cntrl_int    : std_logic_vector(0 to C_NUM_BITS_REG+1);
signal reg2SA_Data_status_int   : std_logic_vector(0 to C_NUM_BITS_REG-1);
signal reg2SA_Data_receive_int  : std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);
signal reg2SA_Data_receive_plb_int:
                                 std_logic_vector(0 to C_SPLB_NATIVE_DWIDTH-1);
signal reg2SA_Data_slvsel_int     : std_logic_vector(0 to C_NUM_SS_BITS-1);
signal reg2SA_Data_TxOccupancy_int:
                                 std_logic_vector(0 to C_OCCUPANCY_NUM_BITS-1);
signal reg2SA_Data_RcOccupancy_int:
                                 std_logic_vector(0 to C_OCCUPANCY_NUM_BITS-1);

--STATUS REGISTER SIGNALS
signal sr_3_MODF_int           : std_logic;
signal sr_4_Tx_Full_int        : std_logic;
signal sr_5_Tx_Empty_int       : std_logic;
signal sr_6_Rx_Full_int        : std_logic;
signal sr_7_Rx_Empty_int       : std_logic;

--RECEIVE AND TRANSMIT REGISTER SIGNALS
signal drr_Overrun_int         : std_logic;
signal dtr_Underrun_strobe_int : std_logic;

--FIFO SIGNALS
signal rc_FIFO_Full_strobe_int : std_logic;
signal rc_FIFO_occ_Reversed_int: std_logic_vector(0 to C_OCCUPANCY_NUM_BITS-1);
signal rc_FIFO_Data_Out_int    : std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);
signal data_Exists_RcFIFO_int  : std_logic;
signal tx_FIFO_Empty_strobe_int: std_logic;
signal tx_FIFO_occ_Reversed_int: std_logic_vector(0 to C_OCCUPANCY_NUM_BITS-1);
signal data_Exists_TxFIFO_int  : std_logic;
signal data_From_TxFIFO_int    : std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);
signal tx_FIFO_less_half_int   : std_logic;
signal reset_TxFIFO_ptr_int    : std_logic;
signal reset_RcFIFO_ptr_int    : std_logic;

signal ip2Bus_Data_Reg_int      : std_logic_vector(0 to C_SPLB_NATIVE_DWIDTH-1);
signal ip2Bus_Data_occupancy_int: std_logic_vector(0 to C_SPLB_NATIVE_DWIDTH-1);
signal ip2Bus_Data_SS_int       : std_logic_vector(0 to C_SPLB_NATIVE_DWIDTH-1);

-- PLBv46 SIGNALS
signal bus2IP_Clk             : std_logic;
signal bus2IP_Reset_int       : std_logic;
signal bus2IP_Data_int        : std_logic_vector
                                (0 to C_SPLB_NATIVE_DWIDTH - 1);

signal bus2IP_Data_processed  : std_logic_vector
                                (0 to C_SPLB_NATIVE_DWIDTH - 1);

signal bus2IP_Addr_int        : std_logic_vector(0 to C_SPLB_AWIDTH - 1 );
signal bus2IP_BE_int          : std_logic_vector
                                (0 to C_SPLB_NATIVE_DWIDTH / 8 - 1 );

signal ip2Bus_Data_int        : std_logic_vector
                                (0 to C_SPLB_NATIVE_DWIDTH - 1):=
                                (others  => '0');
signal ip2Bus_Error_int       : std_logic;
signal ip2Bus_WrAck_int       : std_logic := '0';
signal ip2Bus_RdAck_int       : std_logic := '0';
signal ip2Bus_IntrEvent_int   : std_logic_vector
                                (0 to IP_INTR_MODE_ARRAY'length - 1 );
-- IPIC USED SIGNALS
signal bus2ip_cs              : std_logic_vector
                                (0 to ((ARD_ADDR_RANGE_ARRAY'length)/2)-1);

signal bus2ip_rdce            : std_logic_vector
                                (0 to calc_num_ce(ARD_NUM_CE_ARRAY)-1);

signal bus2ip_wrce            : std_logic_vector
                                (0 to calc_num_ce(ARD_NUM_CE_ARRAY)-1);

signal transmit_ip2bus_error  : std_logic;
signal receive_ip2bus_error   : std_logic;

-- SOFT RESET SIGNALS
signal reset2ip_reset         : std_logic;
signal rst_ip2bus_wrack       : std_logic;
signal rst_ip2bus_error       : std_logic;
signal rst_ip2bus_rdack       : std_logic;

-- INTERRUPT SIGNALS
signal intr_ip2bus_data       : std_logic_vector(0 to C_SPLB_NATIVE_DWIDTH-1);
signal intr_ip2bus_rdack      : std_logic;
signal intr_ip2bus_wrack      : std_logic;
signal intr_ip2bus_error      : std_logic;
signal ip2bus_error_RdWr      : std_logic;

--
signal wr_ce_or_reduce_fifo_no  : std_logic;
signal wr_ce_or_reduce_fifo_yes : std_logic;

signal ip2Bus_WrAck_fifo_no_d1  : std_logic;
signal ip2Bus_WrAck_fifo_no     : std_logic;

signal ip2Bus_WrAck_fifo_yes_d1 : std_logic;
signal ip2Bus_WrAck_fifo_yes    : std_logic;

signal wr_ce_reduce_ack_gen: std_logic;
--
signal rd_ce_or_reduce_fifo_yes : std_logic;
signal rd_ce_or_reduce_fifo_no  : std_logic;

signal ip2Bus_RdAck_fifo_no_d1  : std_logic;
signal ip2Bus_RdAck_fifo_no     : std_logic;

signal ip2Bus_RdAck_fifo_yes_d1 : std_logic;
signal ip2Bus_RdAck_fifo_yes    : std_logic;

signal rd_ce_reduce_ack_gen : std_logic;
--
signal control_bit_7_8_int : std_logic_vector(0 to 1);
--

signal spisel_pulse_o_int       : std_logic;
signal spisel_d1_reg            : std_logic;
signal Mst_N_Slv_mode           : std_logic;
-------------------------------------------------------------------------------
-- Signal and Type Declarations Ends
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Architecture Starts
-------------------------------------------------------------------------------

begin
-----------------------------------
-- Combinatorial operations for SPI
-----------------------------------
-- A write to read only register wont have any effect on register.
-- The transaction is completed by generating WrAck only.

--------------------------------------------------------
-- IP2Bus_Error is generated under following conditions:
-- 1. If an full transmit register/FIFO is written into.
-- 2. If an empty receive register/FIFO is read from.
-- Due to software driver legacy, the register rule test is not applied to SPI.
--------------------------------------------------------

  ip2Bus_Error_int      <= intr_ip2bus_error     or
                           rst_ip2bus_error      or
                           transmit_ip2bus_error or
                           receive_ip2bus_error;

-------------------------
-- SIGNAL_WITHOUT_FIFOS : Signal generation when C_FIFO_EXIST = 0
-------------------------
----------------------
SIGNALS_WITHOUT_FIFOS: if(C_FIFO_EXIST = 0) generate
----------------------
  wr_ce_or_reduce_fifo_no <= bus2ip_wrce(SPISR)  or -- read only register
                             bus2ip_wrce(SPIDRR) or -- read only register
                             bus2ip_wrce(SPIDTR) or -- common to
                                                    -- spi_fifo_ifmodule_1 and
                                                    -- spi_receive_reg_1
                                                    -- (FROM TRANSMITTER) module
                             bus2ip_wrce(SPICR)  or
                             bus2ip_wrce(SPISSR);

-- I_WRITE_ACK_WTHOUT_FIFO: The commong write ACK generation logic when FIFO is
-- ------------------------ not included in the design.
--------------------------------------------------
-- _____|-----|__________  wr_ce_or_reduce_fifo_no
-- ________|-----|_______  ip2Bus_WrAck_fifo_no_d1
-- ________|--|__________  ip2Bus_WrAck_fifo_no from common write ack register
--                         this ack will be used in register files for
--                         reference.
--------------------------------------------------
I_WRITE_ACK_WTHOUT_FIFO: process(Bus2IP_Clk) is
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk = '1') then
      if (reset2ip_reset = RESET_ACTIVE) then
          ip2Bus_WrAck_fifo_no_d1 <= '0';
          ip2Bus_WrAck_fifo_no    <= '0';
      else
          ip2Bus_WrAck_fifo_no_d1 <= wr_ce_or_reduce_fifo_no;
          ip2Bus_WrAck_fifo_no    <= wr_ce_or_reduce_fifo_no and
                                                 (not ip2Bus_WrAck_fifo_no_d1);
      end if;
    end if;
end process I_WRITE_ACK_WTHOUT_FIFO;
-------------------------------------------------
-- internal logic uses this signal

wr_ce_reduce_ack_gen <= ip2Bus_WrAck_fifo_no;
-------------------------------------------------
-- common WrAck to IPIF

ip2Bus_WrAck_int <= intr_ip2bus_wrack  or -- common
                    rst_ip2bus_wrack   or -- common
                    ip2Bus_WrAck_fifo_no;
-------------------------------------------------

rd_ce_or_reduce_fifo_no <= bus2ip_rdce(SWRESET) or -- locally generated in core
                           bus2ip_rdce(SPIDTR)  or
                           bus2ip_rdce(SPISR)   or
                           bus2ip_rdce(SPIDRR)  or -- common to spi_fifo_ifmodule_1
                                                   -- and spi_receive_reg_1
                                                   --(FROM RECEIVER) module
                           bus2ip_rdce(SPICR)   or
                           bus2ip_rdce(SPISSR);

-- I_READ_ACK_WTHOUT_FIFO: The commong read ACK generation logic when FIFO is
-- ----------------------- not included in the design.
-----------------------------------------------
-- _____|------|_________     rd_ce_or_reduce_fifo_no
-- ________|------|______     ip2Bus_RdAck_fifo_no_d1
-- ________|--|__________     ip2Bus_RdAck_fifo_no from common read ack register
-----------------------------------------------
I_READ_ACK_WTHOUT_FIFO: process(Bus2IP_Clk) is
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk = '1') then
      if (reset2ip_reset = RESET_ACTIVE) then
          ip2Bus_RdAck_fifo_no_d1 <= '0';
          ip2Bus_RdAck_fifo_no    <= '0';
      else
          ip2Bus_RdAck_fifo_no_d1 <= rd_ce_or_reduce_fifo_no;
          ip2Bus_RdAck_fifo_no    <= rd_ce_or_reduce_fifo_no and
                                                 (not ip2Bus_RdAck_fifo_no_d1);
      end if;
    end if;
end process I_READ_ACK_WTHOUT_FIFO;
---------------------------------------------
-- internal logic uses this signal

rd_ce_reduce_ack_gen <= ip2Bus_RdAck_fifo_no;
-------------------------------------------------
-- common RdAck to IPIF

ip2Bus_RdAck_int     <= intr_ip2bus_rdack    or      -- common
                        ip2Bus_RdAck_fifo_no;
-------------------------------------------------
end generate SIGNALS_WITHOUT_FIFOS;
-----------------------------------
----------------------
-- SIGNAL_WITH_FIFOS : signal generation when C_FIFO_EXIST = 1
----------------------
SIGNAL_WITH_FIFOS: if(C_FIFO_EXIST = 1) generate
------------------------
wr_ce_or_reduce_fifo_yes <= bus2ip_wrce(SPISR)  or  -- locally generated
                            bus2ip_wrce(SPIDRR) or  -- locally generated
                            bus2ip_wrce(SPIDTR) or  -- common to
                                                    -- spi_fifo_ifmodule_1
                                                    -- and spi_receive_reg_1
                                                    --(FROM TRANSMITTER) module
                            bus2ip_wrce(SPITFOR)or  -- locally generated
                            bus2ip_wrce(SPIRFOR)or  -- locally generated
                            bus2ip_wrce(SPICR)  or  -- spi_cntrl_reg_1
                            bus2ip_wrce(SPISSR);    -- spi_status_reg_1
----------------------------
-- I_WRITE_ACK_FIFO: The commong write ACK generation logic when FIFO is
-- ----------------- included in the design.
-----------------------------------------------
-- _____|-----|__________       wr_ce_or_reduce_fifo_yes
-- ________|-----|_______       ip2Bus_WrAck_fifo_yes_d1
-- ________|--|__________       ip2Bus_WrAck_fifo_yes from common write ack reg
--                              this ack will be used in register files for
--                              reference.
-----------------------------------------------
I_WRITE_ACK_FIFO: process(Bus2IP_Clk) is
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk = '1') then
      if (reset2ip_reset = RESET_ACTIVE) then
          ip2Bus_WrAck_fifo_yes_d1 <= '0';
          ip2Bus_WrAck_fifo_yes    <= '0';
      else
          ip2Bus_WrAck_fifo_yes_d1 <= wr_ce_or_reduce_fifo_yes;
          ip2Bus_WrAck_fifo_yes    <= wr_ce_or_reduce_fifo_yes and
                                                (not ip2Bus_WrAck_fifo_yes_d1);
      end if;
    end if;
end process I_WRITE_ACK_FIFO;
-----------------------------
-- internal logic uses this signal

wr_ce_reduce_ack_gen <= ip2Bus_WrAck_fifo_yes;

-----------------------------

-- common WrAck to IPIF

ip2Bus_WrAck_int <= intr_ip2bus_wrack     or -- common
                    rst_ip2bus_wrack      or -- common
                    ip2Bus_WrAck_fifo_yes;
-------------------------------------------------------------------------------
rd_ce_or_reduce_fifo_yes <= bus2ip_rdce(SWRESET) or --common locally generated
                            bus2ip_rdce(SPIDTR)  or --common locally generated
                            bus2ip_rdce(SPISR)   or --common from status register
                            bus2ip_rdce(SPIDRR)  or --common to
                                                    --spi_fifo_ifmodule_1
                                                    --and spi_receive_reg_1
                                                    --(FROM RECEIVER) module
                            bus2ip_rdce(SPICR)   or --common spi_cntrl_reg_1
                            bus2ip_rdce(SPISSR)  or --common spi_status_reg_1
                            bus2ip_rdce(SPITFOR) or --only for fifo_occu TX reg
                            bus2ip_rdce(SPIRFOR);   --only for fifo_occu RX reg
---------------------------------------------------
-- I_READ_ACK_FIFO: The commong read ACK generation logic when FIFO is
-- ---------------- included in the design.
-----------------------------------------------
-----------------------------------------------
-- _____|-----|__________       rd_ce_or_reduce_fifo_yes
-- ________|-----|_______       ip2Bus_RdAck_fifo_yes_d1
-- ________|--|__________       ip2Bus_RdAck_fifo_yes from common read ack reg
-----------------------------------------------
I_READ_ACK_FIFO: process(Bus2IP_Clk) is
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk = '1') then
      if (reset2ip_reset = RESET_ACTIVE) then
          ip2Bus_RdAck_fifo_yes_d1 <= '0';
          ip2Bus_RdAck_fifo_yes    <= '0';
      else
          ip2Bus_RdAck_fifo_yes_d1 <= rd_ce_or_reduce_fifo_yes;
          ip2Bus_RdAck_fifo_yes    <= rd_ce_or_reduce_fifo_yes and
                                                (not ip2Bus_RdAck_fifo_yes_d1);
      end if;
    end if;
end process I_READ_ACK_FIFO;
----------------------------

-- internal logic uses this signal

rd_ce_reduce_ack_gen <= ip2Bus_RdAck_fifo_yes;
----------------------------

-- common RdAck to IPIF

ip2Bus_RdAck_int <= intr_ip2bus_rdack     or      -- common
                    ip2Bus_RdAck_fifo_yes;
--------------------------------------------

end generate SIGNAL_WITH_FIFOS;
-------------------------------
--*****************************************************************************

ip2Bus_Data_occupancy_int(0 to C_SPLB_NATIVE_DWIDTH-C_OCCUPANCY_NUM_BITS-1)
                         <= (others => '0');

ip2Bus_Data_occupancy_int(C_SPLB_NATIVE_DWIDTH-C_OCCUPANCY_NUM_BITS
                          to C_SPLB_NATIVE_DWIDTH-1)
                 <= reg2SA_Data_RcOccupancy_int or reg2SA_Data_TxOccupancy_int;

-------------------------------------------------------------------------------
-- SPECIAL_CASE_WHEN_SS_NOT_EQL_32 : The Special case is executed whenever
--                                   C_NUM_SS_BITS is less than 32
-------------------------------------------------------------------------------

  SPECIAL_CASE_WHEN_SS_NOT_EQL_32: if(C_NUM_SS_BITS /= 32) generate
  begin
     ip2Bus_Data_SS_int(0 to C_SPLB_NATIVE_DWIDTH-C_NUM_SS_BITS-1)
                       <= (others => '0');
  end generate SPECIAL_CASE_WHEN_SS_NOT_EQL_32;


  ip2Bus_Data_SS_int(C_SPLB_NATIVE_DWIDTH-C_NUM_SS_BITS
                     to C_SPLB_NATIVE_DWIDTH-1)
                     <= reg2SA_Data_slvsel_int;

-------------------------------------------------------------------------------

  ip2Bus_Data_Reg_int(0 to C_SPLB_NATIVE_DWIDTH-C_NUM_BITS_REG-3)
                  <= (others => '0');

  ip2Bus_Data_Reg_int(C_SPLB_NATIVE_DWIDTH-C_NUM_BITS_REG-2
                  to C_SPLB_NATIVE_DWIDTH-C_NUM_BITS_REG-1) <=
                  reg2SA_Data_cntrl_int(0 to 1);-- Two Extra bit in control reg

  ip2Bus_Data_Reg_int(C_SPLB_NATIVE_DWIDTH-C_NUM_BITS_REG
                  to C_SPLB_NATIVE_DWIDTH-1)
               <= reg2SA_Data_cntrl_int(2 to C_NUM_BITS_REG+1) or
                  reg2SA_Data_status_int;

-------------------------------------------------------------------------------

  Receive_Reg_width_is_32: if(C_NUM_TRANSFER_BITS = 32) generate
  begin
      reg2SA_Data_receive_plb_int <= reg2SA_Data_receive_int;
  end generate Receive_Reg_width_is_32;

  Receive_Reg_width_is_not_32: if(C_NUM_TRANSFER_BITS /= 32) generate
  begin
   reg2SA_Data_receive_plb_int(0 to C_SPLB_NATIVE_DWIDTH-C_NUM_TRANSFER_BITS-1)
                              <= (others => '0');
   reg2SA_Data_receive_plb_int(C_SPLB_NATIVE_DWIDTH-C_NUM_TRANSFER_BITS
                              to C_SPLB_NATIVE_DWIDTH-1)
                              <= reg2SA_Data_receive_int;
  end generate Receive_Reg_width_is_not_32;
-------------------------------------------------------------------------------

  ip2Bus_Data_int  <= ip2Bus_Data_occupancy_int or
                      ip2Bus_Data_SS_int        or
                      ip2Bus_Data_Reg_int       or
                      intr_ip2bus_data          or
                      reg2SA_Data_receive_plb_int;

-------------------------------------------------------------------------------

--------------------------------------
-- MAP_SIGNALS_AND_REG_WITHOUT_FIFOS : Signals initialisation and module
--                                     instantiation when C_FIFO_EXIST = 0
--------------------------------------

  MAP_SIGNALS_AND_REG_WITHOUT_FIFOS: if(C_FIFO_EXIST = 0) generate

  begin
     rc_FIFO_Full_strobe_int      <= '0';
     rc_FIFO_occ_Reversed_int     <= (others => '0');
     rc_FIFO_Data_Out_int         <= (others => '0');

     data_Exists_RcFIFO_int       <= '0';

     tx_FIFO_Empty_strobe_int     <= '0';
     tx_FIFO_occ_Reversed_int     <= (others => '0');
     data_Exists_TxFIFO_int       <= '0';
     data_From_TxFIFO_int         <= (others => '0');
     tx_FIFO_less_half_int        <= '0';
     reset_TxFIFO_ptr_int         <= '0';
     reset_RcFIFO_ptr_int         <= '0';
     reg2SA_Data_RcOccupancy_int  <= (others => '0');
     reg2SA_Data_TxOccupancy_int  <= (others => '0');
     sr_4_Tx_Full_int             <= not(sr_5_Tx_Empty_int);
     sr_6_Rx_Full_int             <= not(sr_7_Rx_Empty_int);

     --------------------------------------------------------------------------
     -- below code manipulates the bus2ip_data going towards interrupt control
     -- unit. In FIFO=0, case bit 23 and 25 of IPIER are not applicable.
     bus2IP_Data_processed(0 to 22) <= bus2IP_Data_int(0 to 22);
     bus2IP_Data_processed(23)      <= '0';
     bus2IP_Data_processed(24)      <= bus2IP_Data_int(24);
     bus2IP_Data_processed(25)      <= '0';
     bus2IP_Data_processed(26 to (C_SPLB_NATIVE_DWIDTH-1)) <=
                               bus2IP_Data_int(26 to (C_SPLB_NATIVE_DWIDTH-1));
     --------------------------------------------------------------------------

     -- Interrupt Status Register(IPISR) Mapping
     ip2Bus_IntrEvent_int(8)  <= '0';
     ip2Bus_IntrEvent_int(7)  <= spisel_pulse_o_int;
      ip2Bus_IntrEvent_int(6)  <= '0';
     ip2Bus_IntrEvent_int(5)  <= drr_Overrun_int;
     ip2Bus_IntrEvent_int(4)  <= spiXfer_done_int;
     ip2Bus_IntrEvent_int(3)  <= dtr_Underrun_strobe_int;
     ip2Bus_IntrEvent_int(2)  <= spiXfer_done_int;
     ip2Bus_IntrEvent_int(1)  <= slave_MODF_strobe_int;
     ip2Bus_IntrEvent_int(0)  <= modf_strobe_int;

-------------------------------------------------------------------------------
-- I_RECEIVE_REG : INSTANTIATE RECEIVE REGISTER
-------------------------------------------------------------------------------

       I_RECEIVE_REG: entity xps_spi_v2_02_a.spi_receive_transmit_reg
          generic map
               (
                C_DBUS_WIDTH            => C_SPLB_NATIVE_DWIDTH,
                C_NUM_TRANSFER_BITS     => C_NUM_TRANSFER_BITS
               )
          port map
               (
                Bus2IP_Clk              => Bus2IP_Clk,
                Reset                   => reset2ip_reset,
            --SPI Receiver signals
            --Slave attachment ports
                Bus2IP_Receive_Reg_RdCE => bus2ip_rdce(SPIDRR),
                Receive_ip2bus_error    => receive_ip2bus_error,
            --SPI module ports
                Reg2SA_Data             => reg2SA_Data_receive_int,
                DRR_Overrun             => drr_Overrun_int,
                SR_7_Rx_Empty           => sr_7_Rx_Empty_int,
                IP2Reg_Data             => receive_Data_int,
                SPIXfer_done            => spiXfer_done_int,

            --SPI Transmitter signals
                --Slave attachment ports
                Bus2IP_Data_sa          => bus2IP_Data_int,
                Bus2IP_Transmit_Reg_WrCE=> bus2ip_wrce(SPIDTR),
                transmit_ip2bus_error   => transmit_ip2bus_error,
                --SPI module ports
                Register_Data           => transmit_Data_int,
                SR_5_Tx_Empty           => sr_5_Tx_Empty_int,
                DTR_Underrun_strobe     => dtr_Underrun_strobe_int,
                DTR_underrun            => dtr_underrun_int,
                Wr_ce_reduce_ack_gen    => wr_ce_reduce_ack_gen,
                Rd_ce_reduce_ack_gen    => rd_ce_reduce_ack_gen
               );

end generate MAP_SIGNALS_AND_REG_WITHOUT_FIFOS;

-------------------------------------------------------------------------------
-- MAP_SIGNALS_AND_REG_WITH_FIFOS : Signals initialisation and module
--                                  instantiation when C_FIFO_EXIST = 1
-------------------------------------------------------------------------------
MAP_SIGNALS_AND_REG_WITH_FIFOS: if(C_FIFO_EXIST /= 0) generate

signal IP2Bus_RdAck_receive_enable  : std_logic;
signal IP2Bus_WrAck_transmit_enable : std_logic;

signal data_Exists_RcFIFO_int_d1: std_logic;
signal data_Exists_RcFIFO_pulse : std_logic;

begin
 -- when FIFO = 1, the all the IPIER, IPISR interrupt bits are applicable.
 bus2IP_Data_processed(0 to 22) <= bus2IP_Data_int(0 to 22);
 bus2IP_Data_processed(23)      <= bus2IP_Data_int(23) and
                                   ((not spisel_d1_reg) or
				   (not Mst_N_Slv_mode));
 bus2IP_Data_processed(24)      <= bus2IP_Data_int(24); 
 bus2IP_Data_processed(25 to (C_SPLB_NATIVE_DWIDTH-1)) <=
                               bus2IP_Data_int(25 to (C_SPLB_NATIVE_DWIDTH-1));
 ----------------------------------------------------
 -- _____|-------------  data_Exists_RcFIFO_int
 -- ________|----------  data_Exists_RcFIFO_int_d1
 -- _____|--|__________  data_Exists_RcFIFO_pulse
 ----------------------------------------------------
 I_DRR_NOT_EMPTY_PULSE_P: process(Bus2IP_Clk) is
 begin
     if (Bus2IP_Clk'event and Bus2IP_Clk = '1') then
       if (reset2ip_reset = RESET_ACTIVE) then
           data_Exists_RcFIFO_int_d1 <= '0';
       else
           data_Exists_RcFIFO_int_d1 <= data_Exists_RcFIFO_int;
       end if;
     end if;
 end process I_DRR_NOT_EMPTY_PULSE_P;
 ------------------------------------
     data_Exists_RcFIFO_pulse  <= data_Exists_RcFIFO_int and
                                 (not data_Exists_RcFIFO_int_d1);

     -- Interrupt Status Register(IPISR) Mapping
     ip2Bus_IntrEvent_int(8)  <= data_Exists_RcFIFO_pulse and
                        ((not spisel_d1_reg)or(not Mst_N_Slv_mode));
     ip2Bus_IntrEvent_int(7)  <= spisel_pulse_o_int;

     ip2Bus_IntrEvent_int(6)  <= tx_FIFO_less_half_int;
     ip2Bus_IntrEvent_int(5)  <= drr_Overrun_int;
     ip2Bus_IntrEvent_int(4)  <= rc_FIFO_Full_strobe_int;
     ip2Bus_IntrEvent_int(3)  <= dtr_Underrun_strobe_int;
     ip2Bus_IntrEvent_int(2)  <= tx_FIFO_Empty_strobe_int;
     ip2Bus_IntrEvent_int(1)  <= slave_MODF_strobe_int;
     ip2Bus_IntrEvent_int(0)  <= modf_strobe_int;

     --Combinatorial operations
     reset_TxFIFO_ptr_int     <= reset2ip_reset or register_Data_cntrl_int(4);
     reset_RcFIFO_ptr_int     <= reset2ip_reset or register_Data_cntrl_int(3);
     sr_5_Tx_Empty_int        <= not data_Exists_TxFIFO_int;
     sr_7_Rx_Empty_int        <= not data_Exists_RcFIFO_int;

     --SR_1_Rx_Non_Empty_int    <= data_Exists_RcFIFO_int;--3/25/2010

-------------------------------------------------------------------------------
-- I_RECEIVE_FIFO : INSTANTIATE RECEIVE FIFO
-------------------------------------------------------------------------------
 IP2Bus_RdAck_receive_enable   <= (rd_ce_reduce_ack_gen and
                                   bus2ip_rdce(SPIDRR))
                                   and (not sr_7_Rx_Empty_int);

     I_RECEIVE_FIFO: entity proc_common_v3_00_a.srl_fifo
        generic map
             (
              C_DATA_BITS => C_NUM_TRANSFER_BITS,
              C_DEPTH     => FIFO_DEPTH
             )
        port map
             (
              Clk         => Bus2IP_Clk,
              Reset       => reset_RcFIFO_ptr_int,
              FIFO_Write  => spiXfer_done_int,
              Data_In     => receive_Data_int,
              FIFO_Read   => IP2Bus_RdAck_receive_enable,
              Data_Out    => rc_FIFO_Data_Out_int,
              FIFO_Full   => sr_6_Rx_Full_int,
              Data_Exists => data_Exists_RcFIFO_int,
              Addr        => rc_FIFO_occ_Reversed_int
             );

-------------------------------------------------------------------------------
-- I_TRANSMIT_FIFO : INSTANTIATE TRANSMIT REGISTER
-------------------------------------------------------------------------------
IP2Bus_WrAck_transmit_enable <= (wr_ce_reduce_ack_gen and
                                 bus2ip_wrce(SPIDTR))
                                 and (not sr_4_Tx_Full_int);

     I_TRANSMIT_FIFO: entity proc_common_v3_00_a.srl_fifo
        generic map
             (
              C_DATA_BITS => C_NUM_TRANSFER_BITS,
              C_DEPTH     => FIFO_DEPTH
             )
        port map
             (
              Clk         => Bus2IP_Clk,
              Reset       => reset_TxFIFO_ptr_int,
              FIFO_Write  => IP2Bus_WrAck_transmit_enable,
              Data_In     => bus2IP_Data_int
                             (C_SPLB_NATIVE_DWIDTH-C_NUM_TRANSFER_BITS
                              to C_SPLB_NATIVE_DWIDTH-1),
              FIFO_Read   => spiXfer_done_int,
              Data_Out    => data_From_TxFIFO_int,
              FIFO_Full   => sr_4_Tx_Full_int,
              Data_Exists => data_Exists_TxFIFO_int,
              Addr        => tx_FIFO_occ_Reversed_int
             );

-------------------------------------------------------------------------------
-- I_FIFO_IF_MODULE : INSTANTIATE FIFO INTERFACE MODULE
-------------------------------------------------------------------------------
     I_FIFO_IF_MODULE: entity xps_spi_v2_02_a.spi_fifo_ifmodule
        generic map
             (
              C_NUM_TRANSFER_BITS   => C_NUM_TRANSFER_BITS
             )
        port map
             (
              Bus2IP_Clk            => Bus2IP_Clk,
              Reset                 => reset2ip_reset,

          --Slave attachment ports
              Bus2IP_RcFIFO_RdCE    => bus2ip_rdce(SPIDRR),
              Bus2IP_TxFIFO_WrCE    => bus2ip_wrce(SPIDTR),
              Receive_ip2bus_error  => receive_ip2bus_error,
              Transmit_ip2bus_error => transmit_ip2bus_error,

          --FIFO ports
              Data_From_TxFIFO      => data_From_TxFIFO_int,
              Tx_FIFO_Data_WithZero => transmit_Data_int,
              Rc_FIFO_Data_Out      => rc_FIFO_Data_Out_int,
              Rc_FIFO_Empty         => sr_7_Rx_Empty_int,
              Rc_FIFO_Full          => sr_6_Rx_Full_int,
              Rc_FIFO_Full_strobe   => rc_FIFO_Full_strobe_int,
              Tx_FIFO_Empty         => sr_5_Tx_Empty_int,
              Tx_FIFO_Empty_strobe  => tx_FIFO_Empty_strobe_int,
              Tx_FIFO_Full          => sr_4_Tx_Full_int,
              Tx_FIFO_Occpncy_MSB   => tx_FIFO_occ_Reversed_int
                                       (C_OCCUPANCY_NUM_BITS-1),
              Tx_FIFO_less_half     => tx_FIFO_less_half_int,

          --SPI module ports
              Reg2SA_Data           => reg2SA_Data_receive_int,
              DRR_Overrun           => drr_Overrun_int,
              SPIXfer_done          => spiXfer_done_int,
              DTR_Underrun_strobe   => dtr_Underrun_strobe_int,
              DTR_underrun          => dtr_underrun_int,
              Wr_ce_reduce_ack_gen  => wr_ce_reduce_ack_gen,
              Rd_ce_reduce_ack_gen  => rd_ce_reduce_ack_gen

             );

-------------------------------------------------------------------------------
-- I_TX_OCCUPANCY : INSTANTIATE TRANSMIT OCCUPANCY REGISTER
-------------------------------------------------------------------------------

     I_TX_OCCUPANCY: entity xps_spi_v2_02_a.SPI_occupancy_reg
        generic map
             (
              C_OCCUPANCY_NUM_BITS => C_OCCUPANCY_NUM_BITS
             )
        port map
             (
          --Slave attachment ports
              Bus2IP_Reg_RdCE      => bus2ip_rdce(SPITFOR),
          --FIFO port
              IP2Reg_Data_Reversed => tx_FIFO_occ_Reversed_int,
              Reg2SA_Data          => reg2SA_Data_TxOccupancy_int
             );

-------------------------------------------------------------------------------
-- I_RX_OCCUPANCY : INSTANTIATE RECEIVE OCCUPANCY REGISTER
-------------------------------------------------------------------------------

     I_RX_OCCUPANCY: entity xps_spi_v2_02_a.SPI_occupancy_reg
        generic map
             (
              C_OCCUPANCY_NUM_BITS => C_OCCUPANCY_NUM_BITS
             )
        port map
             (
          --Slave attachment ports
              Bus2IP_Reg_RdCE      => bus2ip_rdce(SPIRFOR),
          --FIFO port
              IP2Reg_Data_Reversed => rc_FIFO_occ_Reversed_int,
              Reg2SA_Data          => reg2SA_Data_RcOccupancy_int
             );

  end generate MAP_SIGNALS_AND_REG_WITH_FIFOS;

-------------------------------------------------------------------------------
-- I_PLBv46_IPIF : INSTANTIATE PLBv46 SLAVE SINGLE
-------------------------------------------------------------------------------

     I_PLBv46_IPIF : entity plbv46_slave_single_v1_01_a.plbv46_slave_single
        generic map
             (
              C_ARD_ADDR_RANGE_ARRAY  => ARD_ADDR_RANGE_ARRAY,
              C_ARD_NUM_CE_ARRAY      => ARD_NUM_CE_ARRAY,
              C_SPLB_P2P              => C_SPLB_P2P,
              C_SPLB_MID_WIDTH        => C_SPLB_MID_WIDTH,
              C_SPLB_NUM_MASTERS      => C_SPLB_NUM_MASTERS,
              C_SPLB_AWIDTH           => C_SPLB_AWIDTH,
              C_SPLB_DWIDTH           => C_SPLB_DWIDTH,
              C_SIPIF_DWIDTH          => C_SPLB_NATIVE_DWIDTH,
              C_FAMILY                => C_FAMILY
             )
        port map
             (
              -- System signals
              SPLB_Clk                => SPLB_Clk,
              SPLB_Rst                => SPLB_Rst,

              -- Bus Slave signals
              PLB_ABus                => PLB_ABus,
              PLB_UABus               => PLB_UABus,
              PLB_PAValid             => PLB_PAValid,
              PLB_SAValid             => PLB_SAValid,
              PLB_rdPrim              => PLB_rdPrim,
              PLB_wrPrim              => PLB_wrPrim,
              PLB_masterID            => PLB_masterID,
              PLB_abort               => PLB_abort,
              PLB_busLock             => PLB_busLock,
              PLB_RNW                 => PLB_RNW,
              PLB_BE                  => PLB_BE,
              PLB_MSize               => PLB_MSize,
              PLB_size                => PLB_size,
              PLB_type                => PLB_type,
              PLB_lockErr             => PLB_lockErr,
              PLB_wrDBus              => PLB_wrDBus,
              PLB_wrBurst             => PLB_wrBurst,
              PLB_rdBurst             => PLB_rdBurst,
              PLB_wrPendReq           => PLB_wrPendReq,
              PLB_rdPendReq           => PLB_rdPendReq,
              PLB_wrPendPri           => PLB_wrPendPri,
              PLB_rdPendPri           => PLB_rdPendPri,
              PLB_reqPri              => PLB_reqPri,
              PLB_TAttribute          => PLB_TAttribute,

              -- Slave Response Signals
              Sl_addrAck              => Sl_addrAck,
              Sl_SSize                => Sl_SSize,
              Sl_wait                 => Sl_wait,
              Sl_rearbitrate          => Sl_rearbitrate,
              Sl_wrDAck               => Sl_wrDAck,
              Sl_wrComp               => Sl_wrComp,
              Sl_wrBTerm              => Sl_wrBTerm,
              Sl_rdDBus               => Sl_rdDBus,
              Sl_rdWdAddr             => Sl_rdWdAddr,
              Sl_rdDAck               => Sl_rdDAck,
              Sl_rdComp               => Sl_rdComp,
              Sl_rdBTerm              => Sl_rdBTerm,
              Sl_MBusy                => Sl_MBusy,
              Sl_MWrErr               => Sl_MWrErr,
              Sl_MRdErr               => Sl_MRdErr,
              Sl_MIRQ                 => Sl_MIRQ,

              -- IP Interconnect (IPIC) port signals
              Bus2IP_Clk              => Bus2IP_Clk,
              Bus2IP_Reset            => bus2IP_Reset_int,
              IP2Bus_Data             => ip2Bus_Data_int,
              IP2Bus_WrAck            => ip2Bus_WrAck_int,
              IP2Bus_RdAck            => ip2Bus_RdAck_int,
              IP2Bus_Error            => ip2Bus_Error_int,
              Bus2IP_Addr             => bus2IP_Addr_int,
              Bus2IP_Data             => bus2IP_Data_int,
              Bus2IP_RNW              => open,
              Bus2IP_BE               => bus2IP_BE_int,
              Bus2IP_CS               => bus2ip_cs,
              Bus2IP_RdCE             => bus2ip_rdce,
              Bus2IP_WrCE             => bus2ip_wrce
             );

-------------------------------------------------------------------------------
-- I_SOFT_RESET : INSTANTIATE SOFT RESET
-------------------------------------------------------------------------------


     I_SOFT_RESET: entity proc_common_v3_00_a.soft_reset
        generic map
             (
              C_SIPIF_DWIDTH     => C_SPLB_NATIVE_DWIDTH,
              -- Width of triggered reset in Bus Clocks
              C_RESET_WIDTH      => 8
             )
        port map
             (
              -- Inputs From the PLBv46 Slave Single Bus
              Bus2IP_Reset       => bus2IP_Reset_int,
              Bus2IP_Clk         => Bus2IP_Clk,
              Bus2IP_WrCE        => bus2ip_wrce(SWRESET),
              Bus2IP_Data        => bus2IP_Data_int,
              Bus2IP_BE          => bus2IP_BE_int,

              -- Final Device Reset Output
              Reset2IP_Reset     => reset2ip_reset,

              -- Status Reply Outputs to the Bus
              Reset2Bus_WrAck    => rst_ip2bus_wrack,
              Reset2Bus_Error    => rst_ip2bus_error,
              Reset2Bus_ToutSup  => open
             );

-------------------------------------------------------------------------------
-- I_INTERRUPT_CONTROL : INSTANTIATE INTERRUPT CONTROLLER
-------------------------------------------------------------------------------

     I_INTERRUPT_CONTROL: entity interrupt_control_v2_01_a.interrupt_control
        generic map
             (
              C_NUM_CE               => 16,
              C_NUM_IPIF_IRPT_SRC    =>  1,  -- Set to 1 to avoid null array
              C_IP_INTR_MODE_ARRAY   => IP_INTR_MODE_ARRAY,
              -- Specifies device Priority Encoder function
              C_INCLUDE_DEV_PENCODER => false,
              -- Specifies device ISC hierarchy
              C_INCLUDE_DEV_ISC      => false,
              C_IPIF_DWIDTH          => C_SPLB_NATIVE_DWIDTH
             )
        port map
             (
              Bus2IP_Clk             =>  Bus2IP_Clk,
              Bus2IP_Reset           =>  reset2ip_reset,
              Bus2IP_Data            =>  bus2IP_Data_processed,--3/30/2010
              Bus2IP_BE              =>  bus2IP_BE_int,
              Interrupt_RdCE         =>  bus2ip_rdce(INTR_LO to INTR_HI),
              Interrupt_WrCE         =>  bus2ip_wrce(INTR_LO to INTR_HI),
              IPIF_Reg_Interrupts    =>  "00", -- Tie off the unused reg intrs
              IPIF_Lvl_Interrupts    =>  "0",  -- Tie off the dummy lvl intr
              IP2Bus_IntrEvent       =>  ip2Bus_IntrEvent_int,
              Intr2Bus_DevIntr       =>  IP2INTC_Irpt,
              Intr2Bus_DBus          =>  intr_ip2bus_data,
              Intr2Bus_WrAck         =>  intr_ip2bus_wrack,
              Intr2Bus_RdAck         =>  intr_ip2bus_rdack,
              Intr2Bus_Error         =>  intr_ip2bus_error,
              Intr2Bus_Retry         =>  open,
              Intr2Bus_ToutSup       =>  open
             );

-------------------------------------------------------------------------------
-- I_CONTROL_REG : INSTANTIATE CONTROL REGISTER
-------------------------------------------------------------------------------

 I_CONTROL_REG_1: entity xps_spi_v2_02_a.spi_cntrl_reg
          generic map
               (
                C_DBUS_WIDTH        => C_SPLB_NATIVE_DWIDTH,
                --Added bit for Mst_xfer_inhibit
                C_NUM_BITS_REG      => C_NUM_BITS_REG+2
               )
          port map
               (
                Bus2IP_Clk          => Bus2IP_Clk,
                Reset               => reset2ip_reset,

            --Slave attachment ports
                Wr_ce_reduce_ack_gen        => wr_ce_reduce_ack_gen,
                Bus2IP_Control_Reg_WrCE     => bus2ip_wrce(SPICR),
                Bus2IP_Control_Reg_RdCE     => bus2ip_rdce(SPICR),
                Bus2IP_Control_Reg_Data     => bus2IP_Data_int,
            --SPI module ports
                Reg2SA_Control_Reg_Data     => reg2SA_Data_cntrl_int,
                Control_Register_Data       => register_Data_cntrl_int,
                control_bit_7_8             => control_bit_7_8_int
                );

-------------------------------------------------------------------------------
-- I_STATUS_REG : INSTANTIATE STATUS REGISTER
-------------------------------------------------------------------------------

       I_STATUS_REG: entity xps_spi_v2_02_a.spi_status_slave_sel_reg
        generic map
             (
              C_NUM_BITS_REG      => C_NUM_BITS_REG,
              C_DBUS_WIDTH        => C_SPLB_NATIVE_DWIDTH,
              C_NUM_SS_BITS       => C_NUM_SS_BITS
             )
        port map
             (
              Bus2IP_Clk          => Bus2IP_Clk,
              Reset               => reset2ip_reset,

          --STATUS REGISTER SIGNALS
          --Slave attachment ports
              Bus2IP_Status_Reg_RdCE    => bus2ip_rdce(SPISR),
              Reg2SA_Status_Reg_Data    => reg2SA_Data_status_int,
            --Reg/FIFO ports
              SR_2_SPISEL_slave         => spisel_d1_reg,
              SR_3_MODF                 => sr_3_MODF_int,
              SR_4_Tx_Full              => sr_4_Tx_Full_int,
              SR_5_Tx_Empty             => sr_5_Tx_Empty_int,
              SR_6_Rx_Full              => sr_6_Rx_Full_int,
              SR_7_Rx_Empty             => sr_7_Rx_Empty_int,
          --SPI module ports
              ModeFault_Strobe          => modf_strobe_int,

          --SLAVE SELECT SIGNALS
              Wr_ce_reduce_ack_gen      => wr_ce_reduce_ack_gen,
              Rd_ce_reduce_ack_gen      => rd_ce_reduce_ack_gen,
              Bus2IP_Slave_Sel_Reg_WrCE => bus2ip_wrce(SPISSR),
              Bus2IP_Slave_Sel_Reg_RdCE => bus2ip_rdce(SPISSR),
              Bus2IP_Data_slave_sel     => bus2IP_Data_int,

              Reg2SA_Slave_Sel_Data     => reg2SA_Data_slvsel_int,
              Slave_Sel_Register_Data   => register_Data_slvsel_int
             );

-------------------------------------------------------------------------------
-- I_SPI_MODULE : INSTANTIATE SPI MODULE
-------------------------------------------------------------------------------

     I_SPI_MODULE: entity xps_spi_v2_02_a.spi_module
        generic map
             (
              C_SCK_RATIO           => C_SCK_RATIO,
              C_NUM_BITS_REG        => C_NUM_BITS_REG+2,
              C_NUM_SS_BITS         => C_NUM_SS_BITS,
              C_NUM_TRANSFER_BITS   => C_NUM_TRANSFER_BITS
             )
        port map
             (
              Bus2IP_Clk            => Bus2IP_Clk,
              Reset                 => reset2ip_reset,

              MODF_strobe           => modf_strobe_int,
              Slave_MODF_strobe     => slave_MODF_strobe_int,
              SR_3_MODF             => sr_3_MODF_int,
              SR_5_Tx_Empty         => sr_5_Tx_Empty_int,
              Control_Reg           => register_Data_cntrl_int,
              Slave_Select_Reg      => register_Data_slvsel_int,
              Transmit_Data         => transmit_Data_int,
              Receive_Data          => receive_Data_int,
              SPIXfer_done          => spiXfer_done_int,
              DTR_underrun          => dtr_underrun_int,

              SPISEL_pulse_op       => spisel_pulse_o_int,
              SPISEL_d1_reg         => spisel_d1_reg,

            --SPI Ports
              SCK_I                 => SCK_I,
              SCK_O                 => SCK_O,
              SCK_T                 => SCK_T,

              MISO_I                => MISO_I,
              MISO_O                => MISO_O,
              MISO_T                => MISO_T,

              MOSI_I                => MOSI_I,
              MOSI_O                => MOSI_O,
              MOSI_T                => MOSI_T,

              SPISEL                => SPISEL,

              SS_I                  => SS_I,
              SS_O                  => SS_O,
              SS_T                  => SS_T,

              control_bit_7_8       => control_bit_7_8_int,
              Mst_N_Slv_mode        => Mst_N_Slv_mode
             );

end imp;
