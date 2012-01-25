-------------------------------------------------------------------------------
--  SPI Occupancy Register Module - entity/architecture pair
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
-- Filename:        spi_occupancy_reg.vhd
-- Version:         v2.02.a
-- Description:     Serial Peripheral Interface (SPI) Module for interfacing
--                  with a 32-bit PLBv46 Bus.Defines logic for occupancy regist
--                  -er.
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
--  SK       04/03/08
-- ~~~~~~
-- -- Created new version of the core.
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
library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------
--                     Definition of Generics
-------------------------------------------------------------------------------

--  C_DBUS_WIDTH                --      Width of the slave data bus
--  C_OCCUPANCY_NUM_BITS        --      Number of bits in occupancy count
--  C_NUM_BITS_REG              --      Width of SPI registers
--  C_NUM_TRANSFER_BITS         --      SPI Serial transfer width.
--                                      Can be 8, 16 or 32 bit wide

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--                  Definition of Ports
-------------------------------------------------------------------------------

-- SYSTEM

--  Bus2IP_Clk                  --      Bus to IP clock
--  Reset                       --      Reset Signal

-- SLAVE ATTACHMENT INTERFACE
--===========================
--  Bus2IP_Reg_RdCE             --      Read CE for occupancy register
--  SPIXfer_done                --      SPI transfer done flag

--  FIFO INTERFACE
--  IP2Reg_Data_Reversed        --      Occupancy data read from FIFO

--  Reg2SA_Data                 --      Data to be send on the bus
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Entity Declaration
-------------------------------------------------------------------------------
entity spi_occupancy_reg is
    generic
    (
        C_OCCUPANCY_NUM_BITS: integer--  --Number of bits in occupancy count
    );
    port
    (
        -- Slave attachment ports
        Bus2IP_Reg_RdCE     : in  std_logic;
        IP2Reg_Data_Reversed: in  std_logic_vector(0 to C_OCCUPANCY_NUM_BITS-1);

        Reg2SA_Data         : out std_logic_vector(0 to C_OCCUPANCY_NUM_BITS-1)
     );
end spi_occupancy_reg;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture imp of spi_occupancy_reg is
-------------------------------------------------------------------------------
-- Signal Declarations
----------------------
begin
-----
--  OCCUPANCY_REG_RD_GENERATE : Occupancy Register Read Generate
-------------------------------
OCCUPANCY_REG_RD_GENERATE: for j in 0 to C_OCCUPANCY_NUM_BITS-1 generate
begin
    Reg2SA_Data(j) <= IP2Reg_Data_Reversed(C_OCCUPANCY_NUM_BITS-1-j) and
                                                             Bus2IP_Reg_RdCE;
end generate OCCUPANCY_REG_RD_GENERATE;

end imp;
--------------------------------------------------------------------------------
