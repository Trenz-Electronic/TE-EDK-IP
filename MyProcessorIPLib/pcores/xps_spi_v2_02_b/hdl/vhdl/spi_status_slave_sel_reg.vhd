-------------------------------------------------------------------------------
--  SPI Status Register Module - entity/architecture pair
-------------------------------------------------------------------------------
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
-- Filename:        spi_status_reg.vhd
-- Version:         v2.02.a
-- Description:     Serial Peripheral Interface (SPI) Module for interfacing
--                  with a 32-bit PLBv46 Bus. The file defines the logic for
--                  status and slave select register.
-------------------------------------------------------------------------------
-- Structure:   This section should show the hierarchical structure of the
--              designs. Separate lines with blank lines if necessary to
--              improve readability.
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
-- History:
--  MZC      1/15/08      -- First version
-- ^^^^^^
--  SK       2/04/08
-- ~~~~~~
-- Optimized the design. combined the files for status and slave select section
-- these files were separate earlier. Also removed the local ACK's generated in
-- the file by a simple logic
-- removed unwanted signals and code cleaning.
-- ^^^^^^
--  SK       04/03/08
-- ~~~~~~
-- -- Created new version of the core.i.e. v2_00_b
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
-- -- CR 543500 is closed.
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

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.RESET_ACTIVE;

-------------------------------------------------------------------------------
--                     Definition of Generics
-------------------------------------------------------------------------------

-- C_NUM_BITS_REG              -- Width of SPI registers
-- C_DBUS_WIDTH                -- Native data bus width 32 bits only
-- C_NUM_SS_BITS               -- Number of bits in slave select
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--                  Definition of Ports
-------------------------------------------------------------------------------

-- SYSTEM
--  Bus2IP_Clk                  --  Bus to IP clock
--  Reset                       --  Reset Signal

-- STATUS REGISTER RELATED SIGNALS
--================================
-- REGISTER/FIFO INTERFACE
-- Bus2IP_Status_Reg_RdCE      -- Status register Read Chip Enable
-- Reg2SA_Status_Reg_Data      -- Status register data to PLB based on PLB read

-- SR_3_modf                   -- Mode fault error status flag
-- SR_4_Tx_Full                -- Transmit register full status flag
-- SR_5_Tx_Empty               -- Transmit register empty status flag
-- SR_6_Rx_Full                -- Receive register full status flag
-- SR_7_Rx_Empty               -- Receive register empty stauts flag
-- ModeFault_Strobe            -- Mode fault strobe

-- SLAVE REGISTER RELATED SIGNALS
--===============================
-- Bus2IP_Slave_Sel_Reg_WrCE   -- slave select register write chip enable
-- Bus2IP_Slave_Sel_Reg_RdCE   -- slave select register read chip enable
-- Bus2IP_Data_slave_sel       -- slave register data from PLB Bus
-- Reg2SA_Slave_Sel_Data       -- Data from slave select register during PLB rd
-- Slave_Sel_Register_Data     -- Data to SPI Module
-- Wr_ce_reduce_ack_gen        -- commaon write ack generation signal
-- Rd_ce_reduce_ack_gen        -- commaon read ack generation signal

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Entity Declaration
-------------------------------------------------------------------------------
entity spi_status_slave_sel_reg is
    generic
    (
        C_NUM_BITS_REG          : integer;    -- Number of bits in SR
        C_DBUS_WIDTH            : integer;    -- 32 bits
        C_NUM_SS_BITS           : integer     -- Number of bits in slave select
    );
    port
    (
       Bus2IP_Clk                 : in  std_logic;
       Reset                      : in  std_logic;
       -- Slave attachment ports
       Bus2IP_Status_Reg_RdCE     : in  std_logic;
       Reg2SA_Status_Reg_Data     : out std_logic_vector(0 to C_NUM_BITS_REG-1);
       -- Reg/FIFO ports

       SR_2_SPISEL_slave          : in  std_logic;
       SR_4_Tx_Full               : in  std_logic;
       SR_5_Tx_Empty              : in  std_logic;
       SR_6_Rx_Full               : in  std_logic;
       SR_7_Rx_Empty              : in  std_logic;
       SR_3_modf                  : out std_logic;
       -- SPI module ports
       ModeFault_Strobe           : in  std_logic;
       -----------------------------------
       Wr_ce_reduce_ack_gen       : in std_logic;
       Rd_ce_reduce_ack_gen       : in std_logic;
       Bus2IP_Slave_Sel_Reg_WrCE  : in  std_logic;
       Bus2IP_Slave_Sel_Reg_RdCE  : in  std_logic;
       Bus2IP_Data_slave_sel      : in  std_logic_vector(0 to C_DBUS_WIDTH-1);
       Reg2SA_Slave_Sel_Data      : out std_logic_vector(0 to C_NUM_SS_BITS-1);
       -- SPI module ports
       Slave_Sel_Register_Data    : out std_logic_vector(0 to C_NUM_SS_BITS-1)
   );
end spi_status_slave_sel_reg;
-------------------------------------------------------------------------------
-- Architecture
---------------
architecture imp of spi_status_slave_sel_reg is
----------------------------------------------------------
-- Signal Declarations
----------------------
signal register_Data_s          : std_logic_vector(0 to C_NUM_BITS_REG-1);
signal modf                     : std_logic;
signal modf_Reset               : std_logic;
----------------------
signal register_Data_int        : std_logic_vector(0 to C_NUM_SS_BITS-1);

----------------------
begin
-------------------------------------------------------------------------------
--  Combinatorial operations
-------------------------------------------------------------------------------
    Reg2SA_Status_Reg_Data(0 to 1)   <= (others => '0');

    register_Data_s(0 to 1) <= (others => '0');
    register_Data_s(2)      <= SR_2_SPISEL_slave;
    register_Data_s(3)      <= modf;
    register_Data_s(4)      <= SR_4_Tx_Full;
    register_Data_s(5)      <= SR_5_Tx_Empty;
    register_Data_s(6)      <= SR_6_Rx_Full;
    register_Data_s(7)      <= SR_7_Rx_Empty;
    -- output signal
    SR_3_modf               <= modf;
-------------------------------------------------------------------------------
--  STATUS_REG_RD_GENERATE : Status Register Read Generate
----------------------------
STATUS_REG_RD_GENERATE: for j in 2 to (C_NUM_BITS_REG-1) generate
begin
    Reg2SA_Status_Reg_Data(j) <= register_Data_s(j) and Bus2IP_Status_Reg_RdCE;
end generate STATUS_REG_RD_GENERATE;
-------------------------------------------------------------------------------
--  I_MODF_REG_PROCESS : Set and Clear modf
------------------------
I_MODF_REG_PROCESS:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        if (modf_Reset = RESET_ACTIVE) then
            modf <= '0';
        elsif (ModeFault_Strobe = '1') then
            modf <= '1';
        end if;
    end if;
end process I_MODF_REG_PROCESS;

modf_Reset <= (Rd_ce_reduce_ack_gen and Bus2IP_Status_Reg_RdCE) or Reset;

--******************************************************************************
-- logic for Slave Select Register

-- Combinatorial operations
----------------------------
Slave_Sel_Register_Data   <= register_Data_int;

-------------------------------------------------------------------------------
--  SLAVE_SEL_REG_GENERATE : Slave Select Register Write Operation
----------------------------
SLAVE_SEL_REG_GENERATE: for j in 0 to (C_NUM_SS_BITS-1) generate
begin
-----
    I_SLAVE_SEL_REG_PROCESS:process(Bus2IP_Clk)
    begin
        if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
            if (Reset = RESET_ACTIVE) then
                register_Data_int(j) <= '1';
        elsif ((Wr_ce_reduce_ack_gen and Bus2IP_Slave_Sel_Reg_WrCE) = '1') then
                register_Data_int(j) <=
                           Bus2IP_Data_slave_sel(C_DBUS_WIDTH-C_NUM_SS_BITS+j);
            end if;
        end if;
    end process I_SLAVE_SEL_REG_PROCESS;
-----
end generate SLAVE_SEL_REG_GENERATE;

-------------------------------------------------------------------------------
--  SLAVE_SEL_REG_RD_GENERATE : Slave Select Register Read Generate
-------------------------------
SLAVE_SEL_REG_RD_GENERATE: for j in 0 to C_NUM_SS_BITS-1 generate
begin
 Reg2SA_Slave_Sel_Data(j) <= register_Data_int(j) and Bus2IP_Slave_Sel_Reg_RdCE;
end generate SLAVE_SEL_REG_RD_GENERATE;
---------------------------------------

end imp;
--------------------------------------------------------------------------------
