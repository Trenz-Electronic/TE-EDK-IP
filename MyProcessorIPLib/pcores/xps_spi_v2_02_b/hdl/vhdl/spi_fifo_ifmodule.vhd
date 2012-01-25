-------------------------------------------------------------------------------
--  SPI FIFO read/write Module -- entity/architecture pair
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
-- Filename:        spi_fifo_ifmodule.vhd
-- Version:         v2.02.a
-- Description:     Serial Peripheral Interface (SPI) Module for interfacing
--                  with a 32-bit PLBv46 Bus. FIFO Interface module
--
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
--  - Removed local ACK generation logic and moved it to the top leve file.
--  --Added RdAck and WrAck signals generated at the top as input to the file
-- ^^^^^^
-- ^^^^^^
--  SK       04/03/08
-- ~~~~~~
-- -- Created new version of the core. i.e. v2_00_b
-- ^^^^^^
--  SK       20/10/08
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
--  C_NUM_TRANSFER_BITS         --  SPI Serial transfer width.
--                                  Can be 8, 16 or 32 bit wide
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--                  Definition of Ports
-------------------------------------------------------------------------------
-- SYSTEM
--  Bus2IP_Clk                  --      Bus to IP clock
--  Reset                       --      Reset Signal

-- SLAVE ATTACHMENT INTERFACE
--  Bus2IP_RcFIFO_RdCE          --      Bus2IP receive FIFO read CE
--  Bus2IP_TxFIFO_WrCE          --      Bus2IP transmit FIFO write CE
--  Rd_ce_reduce_ack_gen         --     commong logid to generate the write ACK
--  Wr_ce_reduce_ack_gen        --      commong logid to generate the write ACK
--  Reg2SA_Data                 --      Data to send on the bus
--  Transmit_ip2bus_error       --      Transmit FIFO error signal
--  Receive_ip2bus_error        --      Receive FIFO error signal

-- FIFO INTERFACE
--  Data_From_TxFIFO            --      Data from transmit FIFO
--  Tx_FIFO_Data_WithZero       --      Components to put zeros on input
--                                      to Shift Register when FIFO is empty
--  Rc_FIFO_Data_Out            --      Receive FIFO data output
--  Rc_FIFO_Empty               --      Receive FIFO empty
--  Rc_FIFO_Full                --      Receive FIFO full
--  Rc_FIFO_Full_strobe         --      1 cycle wide receive FIFO full strobe
--  Tx_FIFO_Empty               --      Transmit FIFO empty
--  Tx_FIFO_Empty_strobe        --      1 cycle wide transmit FIFO full strobe
--  Tx_FIFO_Full                --      Transmit FIFO full
--  Tx_FIFO_Occpncy_MSB         --      Transmit FIFO occupancy register
--                                      MSB bit
--  Tx_FIFO_less_half           --      Transmit FIFO less than half empty

-- SPI MODULE INTERFACE

--  DRR_Overrun                 --      DRR Overrun bit
--  SPIXfer_done                --      SPI transfer done flag
--  DTR_Underrun_strobe         --      DTR Underrun Strobe bit
--  DTR_underrun                --      DTR underrun generation signal
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Entity Declaration
-------------------------------------------------------------------------------
entity spi_fifo_ifmodule is
    generic
    (
        C_NUM_TRANSFER_BITS   : integer
    );
    port
    (
       Bus2IP_Clk           : in  std_logic;
       Reset                : in  std_logic;

       -- Slave attachment ports
       Bus2IP_RcFIFO_RdCE   : in  std_logic;
       Bus2IP_TxFIFO_WrCE   : in  std_logic;

       Reg2SA_Data          : out std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);
       Transmit_ip2bus_error: out std_logic;
       Receive_ip2bus_error : out std_logic;
       -- FIFO ports
       Data_From_TxFIFO     : in  std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);
       Tx_FIFO_Data_WithZero: out std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);
       Rc_FIFO_Data_Out     : in  std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);
       Rc_FIFO_Empty        : in  std_logic;
       Rc_FIFO_Full         : in  std_logic;
       Rc_FIFO_Full_strobe  : out std_logic;
       Tx_FIFO_Empty        : in  std_logic;
       Tx_FIFO_Empty_strobe : out std_logic;
       Tx_FIFO_Full         : in  std_logic;
       Tx_FIFO_Occpncy_MSB  : in  std_logic;
       Tx_FIFO_less_half    : out std_logic;
       -- SPI module ports
       DRR_Overrun          : out std_logic;
       SPIXfer_done         : in  std_logic;
       DTR_Underrun_strobe  : out std_logic;
       DTR_underrun         : in  std_logic;
       Wr_ce_reduce_ack_gen : in  std_logic;
       Rd_ce_reduce_ack_gen : in std_logic
    );
end spi_fifo_ifmodule;

-------------------------------------------------------------------------------
-- Architecture
---------------
architecture imp of spi_fifo_ifmodule is
---------------------------------------------------
-- Signal Declarations
----------------------
signal drr_Overrun_i            :  std_logic;
signal rc_FIFO_Full_d1          :  std_logic;
signal dtr_Underrun_strobe_i    :  std_logic;
signal tx_FIFO_Empty_d1         :  std_logic;
signal tx_FIFO_Occpncy_MSB_d1   :  std_logic;
signal dtr_underrun_d1          :  std_logic;
---------------------------------------------

begin
-----
--  Combinatorial operations
-------------------------------------------------------------------------------
    DRR_Overrun         <= drr_Overrun_i;
    DTR_Underrun_strobe <= dtr_Underrun_strobe_i;

-------------------------------------------------------------------------------
--  I_DRR_OVERRUN_REG_PROCESS : DRR overrun strobe
-------------------------------
I_DRR_OVERRUN_REG_PROCESS:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        drr_Overrun_i <= not(drr_Overrun_i or Reset) and
                                                 Rc_FIFO_Full and SPIXfer_done;
    end if;
end process I_DRR_OVERRUN_REG_PROCESS;

-------------------------------------------------------------------------------
--  SPI_RECEIVE_FIFO_RD_GENERATE : Read of SPI receive FIFO
----------------------------------
SPI_RECEIVE_FIFO_RD_GENERATE: for j in 0 to C_NUM_TRANSFER_BITS-1 generate
begin
     Reg2SA_Data(j) <= Rc_FIFO_Data_Out(j) and(rd_ce_reduce_ack_gen and
                                                           Bus2IP_RcFIFO_RdCE);
end generate SPI_RECEIVE_FIFO_RD_GENERATE;
-------------------------------------------------------------------------------
--  I_RX_ERROR_ACK_REG_PROCESS : Strobe error when receive FIFO is empty
--------------------------------
I_RX_ERROR_ACK_REG_PROCESS:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        Receive_ip2bus_error <= Rc_FIFO_Empty and Bus2IP_RcFIFO_RdCE;
    end if;
end process I_RX_ERROR_ACK_REG_PROCESS;
-------------------------------------------------------------------------------
--  I_RX_FIFO_STROBE_REG_PROCESS : Strobe when receive FIFO is full
----------------------------------
I_RX_FIFO_STROBE_REG_PROCESS:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        if (Reset = RESET_ACTIVE) then
            rc_FIFO_Full_d1 <= '0';
        else
            rc_FIFO_Full_d1 <= Rc_FIFO_Full;
        end if;
    end if;
end process I_RX_FIFO_STROBE_REG_PROCESS;
-----------------------------------------
Rc_FIFO_Full_strobe <= (not rc_FIFO_Full_d1) and Rc_FIFO_Full;
-------------------------------------------------------------------------------
--  I_TX_ERROR_ACK_REG_PROCESS : Strobe error when transmit FIFO is full
--------------------------------
I_TX_ERROR_ACK_REG_PROCESS:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        Transmit_ip2bus_error <= Tx_FIFO_Full and Bus2IP_TxFIFO_WrCE;
    end if;
end process I_TX_ERROR_ACK_REG_PROCESS;
-------------------------------------------------------------------------------
--  PUT_ZEROS_IN_SR_GENERATE : Put zeros on input to SR when FIFO is empty.
--                             Requested by software designers
------------------------------
PUT_ZEROS_IN_SR_GENERATE: for j in 0 to C_NUM_TRANSFER_BITS-1 generate
begin
    Tx_FIFO_Data_WithZero(j) <= Data_From_TxFIFO(j) and (not Tx_FIFO_Empty);
end generate PUT_ZEROS_IN_SR_GENERATE;
-------------------------------------------------------------------------------

--  I_TX_FIFO_STROBE_REG_PROCESS : Strobe when transmit FIFO is empty
----------------------------------
I_TX_FIFO_STROBE_REG_PROCESS:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        if (Reset = RESET_ACTIVE) then
            tx_FIFO_Empty_d1 <= '1';
        else
            tx_FIFO_Empty_d1 <= Tx_FIFO_Empty;
        end if;
    end if;
end process I_TX_FIFO_STROBE_REG_PROCESS;
-----------------------------------------
Tx_FIFO_Empty_strobe <= (not tx_FIFO_Empty_d1) and Tx_FIFO_Empty;

-------------------------------------------------------------------------------
--  I_DTR_UNDERRUN_REG_PROCESS : Strobe to interrupt for transmit data underrun
--                           which happens only in slave mode
-----------------------------
I_DTR_UNDERRUN_REG_PROCESS:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        if (Reset = RESET_ACTIVE) then
            dtr_underrun_d1 <= '0';
        else
            dtr_underrun_d1 <= DTR_underrun;
        end if;
    end if;
end process I_DTR_UNDERRUN_REG_PROCESS;
---------------------------------------
dtr_Underrun_strobe_i <= DTR_underrun and (not dtr_underrun_d1);

-------------------------------------------------------------------------------
--  I_TX_FIFO_HALFFULL_STROBE_REG_PROCESS : Strobe for when transmit FIFO is
--                                          less than half full
-------------------------------------------
I_TX_FIFO_HALFFULL_STROBE_REG_PROCESS:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        if (Reset = RESET_ACTIVE) then
            tx_FIFO_Occpncy_MSB_d1 <= '0';
        else
            tx_FIFO_Occpncy_MSB_d1 <= Tx_FIFO_Occpncy_MSB;
        end if;
    end if;
end process I_TX_FIFO_HALFFULL_STROBE_REG_PROCESS;
--------------------------------------------------

Tx_FIFO_less_half <= tx_FIFO_Occpncy_MSB_d1 and (not Tx_FIFO_Occpncy_MSB);
--------------------------------------------------------------------------
end imp;
--------------------------------------------------------------------------------
