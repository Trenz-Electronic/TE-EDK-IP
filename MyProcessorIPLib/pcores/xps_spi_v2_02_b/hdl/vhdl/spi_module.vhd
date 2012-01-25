----  SPI Module - entity/architecture pair
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
---- ************************************************************************
---- ** DISCLAIMER OF LIABILITY                                            **
---- **                                                                    **
---- ** This file contains proprietary and confidential information of     **
---- ** Xilinx, Inc. ("Xilinx"), that is distributed under a license       **
---- ** from Xilinx, and may be used, copied and/or disclosed only         **
---- ** pursuant to the terms of a valid license agreement with Xilinx.    **
---- **                                                                    **
---- ** XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION              **
---- ** ("MATERIALS") "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER         **
---- ** EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                **
---- ** LIMITATION, ANY WARRANTY WITH RESPECT TO NONINFRINGEMENT,          **
---- ** MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx      **
---- ** does not warrant that functions included in the Materials will     **
---- ** meet the requirements of Licensee, or that the operation of the    **
---- ** Materials will be uninterrupted or error-free, or that defects     **
---- ** in the Materials will be corrected. Furthermore, Xilinx does       **
---- ** not warrant or make any representations regarding use, or the      **
---- ** results of the use, of the Materials in terms of correctness,      **
---- ** accuracy, reliability or otherwise.                                **
---- **                                                                    **
---- ** Xilinx products are not designed or intended to be fail-safe,      **
---- ** or for use in any application requiring fail-safe performance,     **
---- ** such as life-support or safety devices or systems, Class III       **
---- ** medical devices, nuclear facilities, applications related to       **
---- ** the deployment of airbags, or any other applications that could    **
---- ** lead to death, personal injury or severe property or               **
---- ** environmental damage (individually and collectively, "critical     **
---- ** applications"). Customer assumes the sole risk and liability       **
---- ** of any use of Xilinx products in critical applications,            **
---- ** subject only to applicable laws and regulations governing          **
---- ** limitations on product liability.                                  **
---- **                                                                    **
---- ** Copyright 2005, 2006, 2007, 2008, 2009, 2010 Xilinx, Inc.          **
---- ** All rights reserved.                                               **
---- **                                                                    **
---- ** This disclaimer and copyright notice must be retained as part      **
---- ** of this file at all times.                                         **
---- ************************************************************************
----
-------------------------------------------------------------------------------
---- Filename:        spi_module.vhd
---- Version:         v2.02.a
---- Description:     Serial Peripheral Interface (SPI) Module for interfacing
----                  with a 32-bit PLBv46 Bus.
----
-------------------------------------------------------------------------------
-- Structure:   This section should show the hierarchical structure of the
--              designs. Separate lines with blank lines if necessary to
--              improve readability.
--
--              spi_module.vhd
-------------------------------------------------------------------------------
-- Author:      MZC
-- History:
--  MZC      1/15/08      -- First version
-- ^^^^^^
--  SK       2/04/08
-- ~~~~~~
-- -- Update the version of the core.
-- -- Added logic to keep "_T" signals in IOB.
-- ^^^^^^
--  SK       12/04/08
-- ~~~~~~
-- -- Update the version of the core, based upon xps_spi_v2_00_b
-- -- Modified the C_SCK_RATIO = 2 logic in the core.
-- -- Modified the slave mode operation of the core.
-- -- Modified the master mode operation of the core in C_SCK_RATIO > 2 modes.
-- -- Registered the SPISEL and SCK_I signals, which are used in the slave mode.
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
    use ieee.STD_LOGIC_ARITH.ALL;
    use ieee.std_logic_unsigned.all;
    use ieee.numeric_std.all;

library proc_common_v3_00_a;
    use proc_common_v3_00_a.proc_common_pkg.log2;

library unisim;
    use unisim.vcomponents.FD;

-------------------------------------------------------------------------------
--                     Definition of Generics
-------------------------------------------------------------------------------:

--  C_SCK_RATIO                 --      2, 4, 16, 32, , , , 1024, 2048 SPI
--                                      clock ratio (16*N), where N=1,2,3...
--  C_NUM_BITS_REG              --      Width of SPI Control register
--                                      in this module
--  C_NUM_SS_BITS               --      Total number of SS-bits
--  C_NUM_TRANSFER_BITS         --      SPI Serial transfer width.
--                                      Can be 8, 16 or 32 bit wide

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--                  Definition of Ports
-------------------------------------------------------------------------------

-- SYSTEM

--  Bus2IP_Clk                  --      Bus to IP clock
--  Reset                       --      Reset Signal

-- OTHER INTERFACE

--  Slave_MODF_strobe           --      Slave mode fault strobe
--  MODF_strobe                 --      Mode fault strobe
--  SR_3_MODF                   --      Mode fault error flag
--  SR_5_Tx_Empty               --      Transmit Empty
--  Control_Reg                 --      Control Register
--  Slave_Select_Reg            --      Slave Select Register
--  Transmit_Data               --      Data Transmit Register Interface
--  Receive_Data                --      Data Receive Register Interface
--  SPIXfer_done                --      SPI transfer done flag
--  DTR_underrun                --      DTR underrun generation signal

-- SPI INTERFACE

--  SCK_I                       --      SPI Bus Clock Input
--  SCK_O                       --      SPI Bus Clock Output
--  SCK_T                       --      SPI Bus Clock 3-state Enable
--                                      (3-state when high)
--  MISO_I                      --      Master out,Slave in Input
--  MISO_O                      --      Master out,Slave in Output
--  MISO_T                      --      Master out,Slave in 3-state Enable
--  MOSI_I                      --      Master in,Slave out Input
--  MOSI_O                      --      Master in,Slave out Output
--  MOSI_T                      --      Master in,Slave out 3-state Enable
--  SPISEL                      --      Local SPI slave select active low input
--                                      has to be initialzed to VCC
--  SS_I                        --      Input of slave select vector
--                                      of length N input where there are
--                                      N SPI devices,but not connected
--  SS_O                        --      One-hot encoded,active low slave select
--                                      vector of length N ouput
--  SS_T                        --      Single 3-state control signal for
--                                      slave select vector of length N
--                                      (3-state when high)
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Entity Declaration
-------------------------------------------------------------------------------
entity spi_module is
 generic
  (
    C_SCK_RATIO           : integer := 4;
    C_NUM_BITS_REG        : integer := 10;
    C_NUM_SS_BITS         : integer := 1;
    C_NUM_TRANSFER_BITS   : integer := 8
  );
 port
  (
    Bus2IP_Clk          : in  std_logic;
    Reset               : in  std_logic;

    SR_3_MODF           : in  std_logic;
    SR_5_Tx_Empty       : in  std_logic;
    Slave_MODF_strobe   : out std_logic;
    MODF_strobe         : out std_logic;

    --  Control Reg is 10-bit wide
    Control_Reg         : in  std_logic_vector(0 to C_NUM_BITS_REG-1);

    Slave_Select_Reg    : in  std_logic_vector(0 to C_NUM_SS_BITS-1);
    Transmit_Data       : in  std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);

    Receive_Data        : out std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);
    SPIXfer_done        : out std_logic;
    DTR_underrun        : out std_logic;

    SPISEL_pulse_op     : out std_logic;
    SPISEL_d1_reg       : out std_logic;

  --SPI Interface
    SCK_I               : in  std_logic;
    SCK_O               : out std_logic;
    SCK_T               : out std_logic;

    MISO_I              : in  std_logic;
    MISO_O              : out std_logic;
    MISO_T              : out std_logic;

    MOSI_I              : in  std_logic;
    MOSI_O              : out std_logic;
    MOSI_T              : out std_logic;

    SPISEL              : in  std_logic;

    SS_I                : in std_logic_vector(0 to C_NUM_SS_BITS-1);
    SS_O                : out std_logic_vector(0 to C_NUM_SS_BITS-1);
    SS_T                : out std_logic;

    control_bit_7_8     : in std_logic_vector(0 to 1);
    Mst_N_Slv_mode      : out std_logic
);
end spi_module;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture imp of spi_module is

-------------------------------------------------------------------------------
-- Function Declarations
---------------------------------------------------------------------
------------------------
-- spcl_log2 : Performs log2(x) function for value of C_SCK_RATIO > 2
------------------------
function spcl_log2(x : natural) return integer is
    variable j  : integer := 0;
    variable k  : integer := 0;
begin
    if(C_SCK_RATIO /= 2) then
        for i in 0 to 11 loop
            if(2**i >= x) then
               if(k = 0) then
                  j := i;
               end if;
               k := 1;
            end if;
        end loop;
        return j;
    else
        return 2;
    end if;
end spcl_log2;

-------------------------------------------------------------------------------
-- Constant Declarations
------------------------------------------------------------------
constant RESET_ACTIVE : std_logic := '1';
constant COUNT_WIDTH  : INTEGER   := log2(C_NUM_TRANSFER_BITS)+1;

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
signal Ratio_Count               : std_logic_vector
                                   (0 to (spcl_log2(C_SCK_RATIO))-2);
signal Count                     : std_logic_vector
                                   (COUNT_WIDTH downto 0)
                                   := (others => '0');
signal LSB_first                 : std_logic;
signal Mst_Trans_inhibit         : std_logic;
signal Manual_SS_mode            : std_logic;
signal CPHA                      : std_logic;
signal CPOL                      : std_logic;
signal Mst_N_Slv                 : std_logic;
signal SPI_En                    : std_logic;
signal Loop_mode                 : std_logic;
signal transfer_start            : std_logic;
signal transfer_start_d1         : std_logic;
signal transfer_start_pulse      : std_logic;
signal SPIXfer_done_int          : std_logic;
signal SPIXfer_done_int_d1       : std_logic;
signal SPIXfer_done_int_pulse    : std_logic;
signal SPIXfer_done_int_pulse_d1 : std_logic;
signal sck_o_int                 : std_logic;
signal sck_o_in                  : std_logic;
signal Count_trigger             : std_logic;
signal Count_trigger_d1          : std_logic;
signal Count_trigger_pulse       : std_logic;
signal Sync_Set                  : std_logic;
signal Sync_Reset                : std_logic;
signal Serial_Dout               : std_logic;
signal Serial_Din                : std_logic;
signal Shift_Reg                 : std_logic_vector
                                   (0 to C_NUM_TRANSFER_BITS-1);
signal SS_Asserted               : std_logic;
signal SS_Asserted_1dly          : std_logic;
signal Allow_Slave_MODF_Strobe   : std_logic;
signal Allow_MODF_Strobe         : std_logic;
signal Loading_SR_Reg_int        : std_logic;
signal sck_i_d1                  : std_logic;
signal spisel_d1                 : std_logic;
signal spisel_pulse              : std_logic;
signal rising_edge_sck_i         : std_logic;
signal falling_edge_sck_i        : std_logic;
signal edge_sck_i                : std_logic;

signal MODF_strobe_int           : std_logic;
signal master_tri_state_en_control: std_logic;
signal slave_tri_state_en_control: std_logic;

-- following signals are added for use in variouos clock ratio modes.
signal sck_d1                    : std_logic;
signal sck_d2                    : std_logic;
signal sck_fe                    : std_logic;
signal rx_shft_reg               : std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);
signal SPIXfer_done_int_pulse_d2 : std_logic;
--
attribute IOB                                   : string;
attribute IOB of SPI_TRISTATE_CONTROL_II        : label is "true";
attribute IOB of SPI_TRISTATE_CONTROL_III       : label is "true";
attribute IOB of SPI_TRISTATE_CONTROL_IV        : label is "true";
attribute IOB of SPI_TRISTATE_CONTROL_V         : label is "true";
attribute IOB of OTHER_RATIO_GENERATE           : label is "true";

attribute IOB of SCK_I_REG                     : label is "true";
attribute IOB of SPISEL_REG                    : label is "true";

-- added synchronization signals for SPISEL and SCK_I
signal SPISEL_sync : std_logic;
signal SCK_I_sync : std_logic;

-- following register are declared for making data path clear in different modes
signal rx_shft_reg_s : std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);
signal rx_shft_reg_mode_0011 : std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);
signal rx_shft_reg_mode_0110 : std_logic_vector(0 to C_NUM_TRANSFER_BITS-1);

signal sck_fe1 : std_logic;
signal sck_d21 : std_logic;
signal sck_d11 : std_logic;

signal SCK_O_1 : std_logic;
-------------------------------------------------------------------------------
-- Architecture Starts
-------------------------------------------------------------------------------

begin
-------------------------------------------------------------------------------
-- Combinatorial operations
-------------------------------------------------------------------------------

LSB_first                       <= Control_Reg(0);
Mst_Trans_inhibit               <= Control_Reg(1);
Manual_SS_mode                  <= Control_Reg(2);
CPHA                            <= Control_Reg(5);
CPOL                            <= Control_Reg(6);
Mst_N_Slv                       <= Control_Reg(7);
SPI_En                          <= Control_Reg(8);
Loop_mode                       <= Control_Reg(9);
MOSI_O                          <= Serial_Dout;
MISO_O                          <= Serial_Dout;

Mst_N_Slv_mode			<= Control_Reg(7);
--* ---------------------------------------------------------------------------
--* -- MASTER_TRIST_EN_PROCESS : If not master make tristate enabled
--* ----------------------------
master_tri_state_en_control <= '0' when (
                     (control_bit_7_8(0)='1') and -- decides master_n_slave mode
                     (control_bit_7_8(1)='1') and -- decide the spi_en
                     ((MODF_strobe_int or SR_3_MODF)='0')
                                        ) else
                            '1';

SPI_TRISTATE_CONTROL_II: component FD
   generic map
        (
        INIT => '1'
        )
   port map
        (
        Q  => SCK_T,
        C  => Bus2IP_Clk,
        D  => master_tri_state_en_control
        );

SPI_TRISTATE_CONTROL_III: component FD
   generic map
        (
        INIT => '1'
        )
   port map
        (
        Q  => MOSI_T,
        C  => Bus2IP_Clk,
        D  => master_tri_state_en_control
        );

SPI_TRISTATE_CONTROL_IV: component FD
   generic map
        (
        INIT => '1'
        )
   port map
        (
        Q  => SS_T,
        C  => Bus2IP_Clk,
        D  => master_tri_state_en_control
        );
--* ---------------------------------------------------------------------------
--* -- SLAVE_TRIST_EN_PROCESS : If not slave make tristate enabled
--* ---------------------------
slave_tri_state_en_control <= '0' when (
                     (control_bit_7_8(0)='0') and -- decides master_n_slave mode
                     (control_bit_7_8(1)='1') and -- decide the spi_en
                     (SPISEL_sync = '0')
                                     ) else
                            '1';

SPI_TRISTATE_CONTROL_V: component FD
   generic map
        (
        INIT => '1'
        )
   port map
        (
        Q  => MISO_T,
        C  => Bus2IP_Clk,
        D  => slave_tri_state_en_control
        );
-------------------------------------------------------------------------------
-- DTR_UNDERRUN_PROCESS : For Generating DTR underrun error
-------------------------
DTR_UNDERRUN_PROCESS: process(Bus2IP_Clk)
begin
    if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
        if(Reset = RESET_ACTIVE or SPISEL = '1' or Mst_N_Slv = '1') then
            DTR_underrun <= '0';
        elsif(Mst_N_Slv = '0' and SPI_En = '1') then
            if (SR_5_Tx_Empty = '1') then
                if(SPIXfer_done_int_pulse_d1 = '1') then
                    DTR_underrun <= '1';
                end if;
            else
                DTR_underrun <= '0';
            end if;
        end if;
    end if;
end process DTR_UNDERRUN_PROCESS;

-------------------------------------------------------------------------------
-- SPISEL_SYNC: first synchronize the incoming signal, this is required is slave
--------------- mode of the core.

SPISEL_REG: component FD
   generic map
        (
        INIT => '1' -- default '1' to make the device in default master mode
        )
   port map
        (
        Q  => SPISEL_sync,
        C  => Bus2IP_Clk,
        D  => SPISEL
        );

-- SPISEL_DELAY_1CLK_PROCESS : Detect active SCK edge in slave mode
-----------------------------
SPISEL_DELAY_1CLK_PROCESS: process(Bus2IP_Clk)
begin
    if(Bus2IP_Clk'event and Bus2IP_Clk = '1')then
        if(Reset = RESET_ACTIVE) then
            spisel_d1 <= '1';
        else
            spisel_d1 <= SPISEL_sync;
        end if;
    end if;
end process SPISEL_DELAY_1CLK_PROCESS;

-- spisel pulse generating logic
-- this one clock cycle pulse will be available for data loading into
-- shift register
spisel_pulse <= (not SPISEL_sync) and spisel_d1;

-- --------|__________ -- SPISEL
-- ----------|________ -- SPISEL_sync
-- ------------|______ -- spisel_d1
-- __________|--|_____ -- SPISEL_pulse_op
SPISEL_pulse_op       <= spisel_pulse;
SPISEL_d1_reg         <= spisel_d1;
-------------------------------------------------------------------------------
--SCK_I_SYNC: first synchronize incomming signal
-------------

SCK_I_REG: component FD
   generic map
        (
        INIT => '0'
        )
   port map
        (
        Q  => SCK_I_sync,
        C  => Bus2IP_Clk,
        D  => SCK_I
        );
------------------------------------------------------------------
-- SCK_I_DELAY_1CLK_PROCESS : Detect active SCK edge in slave mode on PLB edge
----------------------------- This is purposfully done in the code as the
                         -- data in the internal registers will be registered
                         -- one clock cycle delay of the SCK_I rising edge.
SCK_I_DELAY_1CLK_PROCESS: process(Bus2IP_Clk)
begin
    if(Bus2IP_Clk'event and Bus2IP_Clk = '1')then
        if(Reset = RESET_ACTIVE) then
            sck_i_d1 <= '0';
        else
            sck_i_d1 <= SCK_I_sync;
        end if;
    end if;
end process SCK_I_DELAY_1CLK_PROCESS;
--------------------------------------
--RISING_EDGE_CLK_RATIO_4_GEN : Due to internal logic limitations the
--                              SCK_RATIO=4 mode SCK_I signal is
--                              synchronised with external clock
RISING_EDGE_CLK_RATIO_4_GEN : if C_SCK_RATIO = 4 generate
begin
     -- generate a SCK control pulse for rising edge as well as falling edge
    rising_edge_sck_i  <= SCK_I and (not(SCK_I_sync)) and (not(SPISEL_sync));
    falling_edge_sck_i <= (not(SCK_I) and SCK_I_sync) and (not(SPISEL_sync));

end generate RISING_EDGE_CLK_RATIO_4_GEN;
-----------------------------------------
--RISING_EDGE_CLK_RATIO_OTHERS_GEN: In other modes of SCK_RATIO SCK_I signal is
--                              synchronised with internal clock first then
--                             used, so this will be available in 2nd PLB clock
RISING_EDGE_CLK_RATIO_OTHERS_GEN : if (C_SCK_RATIO /= 2) and (C_SCK_RATIO /= 4)
                                                                       generate
begin
     -- generate a SCK control pulse for rising edge as well as falling edge
   rising_edge_sck_i  <= SCK_I_sync and (not(sck_i_d1)) and (not(SPISEL_sync));
   falling_edge_sck_i <= (not(SCK_I_sync) and sck_i_d1) and (not(SPISEL_sync));

end generate RISING_EDGE_CLK_RATIO_OTHERS_GEN;


-- combine rising edge as well as falling edge as a single signal
edge_sck_i         <= rising_edge_sck_i or falling_edge_sck_i;

-------------------------------------------------------------------------------
-- TRANSFER_START_PROCESS : Generate transfer start signal. When the transfer
--                          gets completed, SPI Transfer done strobe pulls
--                          transfer_start back to zero.
---------------------------
TRANSFER_START_PROCESS: process(Bus2IP_Clk)
begin
    if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
        if(Reset             = RESET_ACTIVE or
            (
             Mst_N_Slv         = '1' and  -- If Master Mode
             (
              SPI_En            = '0' or  -- enable not asserted or
              SR_5_Tx_Empty     = '1' or  -- no data in Tx reg/FIFO or
              SR_3_MODF         = '1' or  -- mode fault error
              Mst_Trans_inhibit = '1'     -- Do not start if Mst xfer inhibited
             )
            ) or
            (
             Mst_N_Slv         = '0' and  -- If Slave Mode
             (
              SPI_En            = '0'   -- enable not asserted or
             )
            )
          )then

            transfer_start <= '0';
        else
-- Delayed SPIXfer_done_int_pulse to work for synchronous design and to remove
-- asserting of loading_sr_reg in master mode after SR_5_Tx_Empty goes to 1
                if(SPIXfer_done_int_pulse = '1' or
                   SPIXfer_done_int_pulse_d1 = '1' or
                   SPIXfer_done_int_pulse_d2='1') then -- this is added to remove
                                                       -- glitch at the end of
                                                       -- transfer in AUTO mode
                        transfer_start <= '0'; -- Set to 0 for at least 1 period
                else
                        transfer_start <= '1'; -- Proceed with SPI Transfer
                end if;
        end if;
    end if;
end process TRANSFER_START_PROCESS;

-------------------------------------------------------------------------------
-- TRANSFER_START_1CLK_PROCESS : Delay transfer start by 1 clock cycle
--------------------------------
TRANSFER_START_1CLK_PROCESS: process(Bus2IP_Clk)
begin
    if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
        if(Reset = RESET_ACTIVE) then
            transfer_start_d1 <= '0';
        else
            transfer_start_d1 <= transfer_start;
        end if;
    end if;
end process TRANSFER_START_1CLK_PROCESS;

-- transfer start pulse generating logic
transfer_start_pulse <= transfer_start and (not(transfer_start_d1));

-------------------------------------------------------------------------------
-- TRANSFER_DONE_PROCESS : Generate SPI transfer done signal
--------------------------
TRANSFER_DONE_PROCESS: process(Bus2IP_Clk)
begin
    if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
        if(Reset = RESET_ACTIVE) then
            SPIXfer_done_int <= '0';
        elsif (transfer_start_pulse = '1') then
            SPIXfer_done_int <= '0';
        elsif (Count(COUNT_WIDTH) = '1') then
            SPIXfer_done_int <= '1';
        end if;
    end if;
end process TRANSFER_DONE_PROCESS;

-------------------------------------------------------------------------------
-- TRANSFER_DONE_1CLK_PROCESS : Delay SPI transfer done signal by 1 clock cycle
-------------------------------
TRANSFER_DONE_1CLK_PROCESS: process(Bus2IP_Clk)
begin
    if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
        if(Reset = RESET_ACTIVE) then
            SPIXfer_done_int_d1 <= '0';
        else
            SPIXfer_done_int_d1 <= SPIXfer_done_int;
        end if;
    end if;
end process TRANSFER_DONE_1CLK_PROCESS;
--
-- transfer done pulse generating logic
SPIXfer_done_int_pulse <= SPIXfer_done_int and (not(SPIXfer_done_int_d1));

-------------------------------------------------------------------------------
-- TRANSFER_DONE_PULSE_DLY_PROCESS : Delay SPI transfer done pulse by 1 and 2
--                                   clock cycles
------------------------------------
-- Delay the Done pulse by a further cycle. This is used as the output Rx
-- data strobe when C_SCK_RATIO = 2
TRANSFER_DONE_PULSE_DLY_PROCESS: process(Bus2IP_Clk)
begin
    if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
        if(Reset = RESET_ACTIVE) then
            SPIXfer_done_int_pulse_d1 <= '0';
            SPIXfer_done_int_pulse_d2 <= '0';
        else
            SPIXfer_done_int_pulse_d1 <= SPIXfer_done_int_pulse;
            SPIXfer_done_int_pulse_d2 <= SPIXfer_done_int_pulse_d1;
        end if;
    end if;
end process TRANSFER_DONE_PULSE_DLY_PROCESS;

-------------------------------------------------------------------------------
-- RX_DATA_GEN1: Only for C_SCK_RATIO = 2 mode.
----------------

RX_DATA_GEN1 : if C_SCK_RATIO = 2 generate
begin

-- This is mux to choose the data register for SPI mode 00,11 and 01,10.
 rx_shft_reg <= rx_shft_reg_mode_0011
              when ((CPOL = '0' and CPHA = '0') or (CPOL = '1' and CPHA = '1'))
              else rx_shft_reg_mode_0110
              when ((CPOL = '0' and CPHA = '1') or (CPOL = '1' and CPHA = '0'))
              else
              (others=>'0');

-- RECEIVE_DATA_STROBE_PROCESS : Strobe data from shift register to receive
--                               data register
--------------------------------
-- For a SCK ratio of 2 the Done needs to be delayed by an extra cycle
-- due to the serial input being captured on the falling edge of the PLB
-- clock. this is purely required for dealing with the real SPI slave memories.

 RECEIVE_DATA_STROBE_PROCESS: process(Bus2IP_Clk)
 begin
     if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
         if(SPIXfer_done_int_pulse_d1 = '1') then
             if(Loop_mode = '1') then
                if (LSB_first = '1') then
                    for i in 0 to C_NUM_TRANSFER_BITS-1 loop
                       Receive_Data(i) <= Shift_Reg(C_NUM_TRANSFER_BITS-1-i);
                    end loop;
                else
                    Receive_Data <= Shift_Reg;
                end if;
             else
                if (LSB_first = '1') then
                    for i in 0 to C_NUM_TRANSFER_BITS-1 loop
                        Receive_Data(i) <= rx_shft_reg(C_NUM_TRANSFER_BITS-1-i);
                    end loop;
                else
                   Receive_Data <= rx_shft_reg;
                end if;
             end if;

         end if;
     end if;
 end process RECEIVE_DATA_STROBE_PROCESS;

    -- Done strobe delayed to match receive data
    SPIXfer_done <= SPIXfer_done_int_pulse_d2;
-------------------------------------------------
end generate RX_DATA_GEN1;
-------------------------------------------------------------------------------

-- RX_DATA_GEN_OTHER_RATIOS: This logic is for other SCK ratios than
---------------------------- C_SCK_RATIO =2

RX_DATA_GEN_OTHER_RATIOS : if C_SCK_RATIO /= 2 generate
begin

-- This is mux to choose the data register for SPI mode 00,11 and 01,10.
-- the below mux is applicable only for Master mode of SPI.
  rx_shft_reg <= rx_shft_reg_mode_0011
              when ((CPOL = '0' and CPHA = '0') or (CPOL = '1' and CPHA = '1'))
              else rx_shft_reg_mode_0110
              when ((CPOL = '0' and CPHA = '1') or (CPOL = '1' and CPHA = '0'))
              else
              (others=>'0');

--  RECEIVE_DATA_STROBE_PROCESS_OTHER_RATIO: the below process if for other
--------------------------------------------  SPI ratios of C_SCK_RATIO >2
--                                        -- It multiplexes the data stored
--                                        -- in internal registers in LSB and
--                                        -- non-LSB modes, in master as well as
--                                        -- in slave mode.
  RECEIVE_DATA_STROBE_PROCESS_OTHER_RATIO: process(Bus2IP_Clk)
  begin
      if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          if(SPIXfer_done_int_pulse_d1 = '1') then
              if (Mst_N_Slv = '1') then -- in master mode
                  if (LSB_first = '1') then
                     for i in 0 to C_NUM_TRANSFER_BITS-1 loop
                        Receive_Data(i) <= rx_shft_reg(C_NUM_TRANSFER_BITS-1-i);
                     end loop;
                  else
                     Receive_Data <= rx_shft_reg;
                  end if;
              elsif(Mst_N_Slv = '0') then -- in slave mode
                  if (LSB_first = '1') then
                     for i in 0 to C_NUM_TRANSFER_BITS-1 loop
                        Receive_Data(i) <= rx_shft_reg_s
                                                      (C_NUM_TRANSFER_BITS-1-i);
                     end loop;
                  else
                     Receive_Data <= rx_shft_reg_s;
                  end if;
              end if;
          end if;
      end if;
  end process RECEIVE_DATA_STROBE_PROCESS_OTHER_RATIO;

  SPIXfer_done <= SPIXfer_done_int_pulse_d2;
--------------------------------------------
end generate RX_DATA_GEN_OTHER_RATIOS;

-------------------------------------------------------------------------------
-- OTHER_RATIO_GENERATE : Logic to be used when C_SCK_RATIO is not equal to 2
-------------------------
OTHER_RATIO_GENERATE: if(C_SCK_RATIO /= 2) generate
begin
-----
-------------------------------------------------------------------------------
-- EXTERNAL_INPUT_OR_LOOP_PROCESS : Select between external data input and
--                                  internal looped data (serial data out to
--                                  serial data in)
-----------------------------------
  EXTERNAL_INPUT_OR_LOOP_PROCESS: process(Bus2IP_Clk)
  begin
      if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          if(SPI_En = '0' or Reset = RESET_ACTIVE) then
              Serial_Din <= '0';      --Clear when disabled SPI device or reset
          elsif(Mst_N_Slv = '1' )then --and Count (0) = '0') then
              if(Loop_mode = '1') then        --Loop mode
                  Serial_Din <= Serial_Dout;  --Loop data in shift register
              else
                  Serial_Din <= MISO_I;
              end if;
          elsif(Mst_N_Slv = '0') then
              Serial_Din <= MOSI_I;
          end if;
      end if;
  end process EXTERNAL_INPUT_OR_LOOP_PROCESS;

-------------------------------------------------------------------------------
-- RATIO_COUNT_PROCESS : Counter which counts from (C_SCK_RATIO/2)-1 down to 0
--                       Used for counting the time to control SCK_O generation
--                       depending on C_SCK_RATIO
------------------------
  RATIO_COUNT_PROCESS: process(Bus2IP_Clk)
  begin
      if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          if(Reset = RESET_ACTIVE or transfer_start = '0') then
              Ratio_Count <= CONV_STD_LOGIC_VECTOR(
                             (C_SCK_RATIO/2)-1,spcl_log2(C_SCK_RATIO)-1);
          else
              Ratio_Count <= Ratio_Count - 1;
              if (Ratio_Count = 0) then
                  Ratio_Count <= CONV_STD_LOGIC_VECTOR(
                                 (C_SCK_RATIO/2)-1,spcl_log2(C_SCK_RATIO)-1);
              end if;
          end if;
      end if;
  end process RATIO_COUNT_PROCESS;

-------------------------------------------------------------------------------
-- COUNT_TRIGGER_GEN_PROCESS : Generate a trigger whenever Ratio_Count reaches
--                             zero
------------------------------
  COUNT_TRIGGER_GEN_PROCESS: process(Bus2IP_Clk)
  begin
      if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          if(Reset = RESET_ACTIVE or transfer_start = '0') then
              Count_trigger <= '0';
          elsif(Ratio_Count = 0) then
              Count_trigger <= not Count_trigger;
          end if;
      end if;
  end process COUNT_TRIGGER_GEN_PROCESS;

-------------------------------------------------------------------------------
-- COUNT_TRIGGER_1CLK_PROCESS : Delay cnt_trigger signal by 1 clock cycle
-------------------------------
  COUNT_TRIGGER_1CLK_PROCESS: process(Bus2IP_Clk)
  begin
      if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          if(Reset = RESET_ACTIVE or transfer_start = '0') then
              Count_trigger_d1 <= '0';
          else
              Count_trigger_d1 <=  Count_trigger;
          end if;
      end if;
  end process COUNT_TRIGGER_1CLK_PROCESS;

 -- generate a trigger pulse for rising edge as well as falling edge
  Count_trigger_pulse <= (Count_trigger and (not(Count_trigger_d1))) or
                        ((not(Count_trigger)) and Count_trigger_d1);

-------------------------------------------------------------------------------
-- SCK_CYCLE_COUNT_PROCESS : Counts number of trigger pulses provided. Used for
--                           controlling the number of bits to be transfered
--                           based on generic C_NUM_TRANSFER_BITS
----------------------------
  SCK_CYCLE_COUNT_PROCESS: process(Bus2IP_Clk)
  begin
      if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          if(Reset = RESET_ACTIVE) then
              Count <= (others => '0');
          elsif (Mst_N_Slv = '1') then
              if (transfer_start = '0') then
                  Count <= (others => '0');
              elsif (Count_trigger_pulse = '1') then
                  Count <=  Count + 1;
                  if (Count(COUNT_WIDTH) = '1') then
                      Count <= (others => '0');
                  end if;
              end if;
          elsif (Mst_N_Slv = '0') then
              if (transfer_start = '0' or SPISEL_sync = '1') then
                  Count <= (others => '0');
              elsif (edge_sck_i = '1') then
                  Count <=  Count + 1;
                  if (Count(COUNT_WIDTH) = '1') then
                      Count <= (others => '0');
                  end if;
              end if;
          end if;
      end if;
  end process SCK_CYCLE_COUNT_PROCESS;

-------------------------------------------------------------------------------
-- SCK_SET_RESET_PROCESS : Sync set/reset toggle flip flop controlled by
--                         transfer_start signal
--------------------------
  SCK_SET_RESET_PROCESS: process(Bus2IP_Clk)
  begin
      if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          if(Reset = RESET_ACTIVE or Sync_Reset = '1' or Mst_N_Slv='0') then
               sck_o_int <= '0';
          elsif(Sync_Set = '1') then
               sck_o_int <= '1';
          elsif (transfer_start = '1') then
                sck_o_int <= sck_o_int xor Count_trigger_pulse;
          end if;
      end if;
  end process SCK_SET_RESET_PROCESS;
------------------------------------
-- DELAY_CLK: Delay the internal clock for a cycle to generate internal enable
--         -- signal for data register.
-------------
DELAY_CLK: process(Bus2IP_Clk)
  begin
     if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
        if (Reset = RESET_ACTIVE)then
           sck_d1 <= '0';
           sck_d2 <= '0';
        else
           sck_d1 <= sck_o_int;
           sck_d2 <= sck_d1;
        end if;
     end if;
  end process DELAY_CLK;
------------------------------------

-- CAPT_RX_FE_MODE_00_11: The below logic is the date registery process for
------------------------- SPI modes of 00 and 11.
CAPT_RX_FE_MODE_00_11 : process(Bus2IP_Clk)
begin
    if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
        if (Reset = RESET_ACTIVE)then
              rx_shft_reg_mode_0011 <= (others => '0');
        elsif(sck_fe = '1' and transfer_start='1') then
             rx_shft_reg_mode_0011<= rx_shft_reg_mode_0011
                                    (1 to (C_NUM_TRANSFER_BITS-1)) & Serial_Din;
        end if;
    end if;
end process CAPT_RX_FE_MODE_00_11;

  -- Falling egde pulse
  sck_fe <= not(sck_d2) and  sck_d1;

-- CAPT_RX_FE_MODE_01_10 : The below logic is the date registery process for
------------------------- SPI modes of 01 and 10.
CAPT_RX_FE_MODE_01_10 : process(Bus2IP_Clk)
  begin
      --if rising_edge(Bus2IP_Clk) then
      if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          if (Reset = RESET_ACTIVE)then
                rx_shft_reg_mode_0110 <= (others => '0');
          elsif (sck_fe1 = '1' and transfer_start = '1') then
                rx_shft_reg_mode_0110 <= rx_shft_reg_mode_0110
                                    (1 to (C_NUM_TRANSFER_BITS-1)) & Serial_Din;
          end if;
      end if;
  end process CAPT_RX_FE_MODE_01_10;

  sck_fe1 <= (not sck_d1) and sck_d2;
-------------------------------------------------------------------------------
-- CAPTURE_AND_SHIFT_PROCESS : This logic essentially controls the entire
--                             capture and shift operation for serial data
------------------------------
  CAPTURE_AND_SHIFT_PROCESS: process(Bus2IP_Clk)
  begin
      if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          if(Reset = RESET_ACTIVE) then
              Shift_Reg(0) <= '0';
              Shift_Reg(1) <= '1';
              Shift_Reg(2 to C_NUM_TRANSFER_BITS -1) <= (others => '0');
              Serial_Dout <= '1';
          elsif(Mst_N_Slv = '1' and not(Count(COUNT_WIDTH) = '1')) then
              if(Loading_SR_Reg_int = '1') then
                  if(LSB_first = '1') then
                      for i in 0 to C_NUM_TRANSFER_BITS-1 loop
                          Shift_Reg(i) <= Transmit_Data
                                          (C_NUM_TRANSFER_BITS-1-i);
                      end loop;
                      Serial_Dout <= Transmit_Data(C_NUM_TRANSFER_BITS-1);
                  else
                      Shift_Reg   <= Transmit_Data;
                      Serial_Dout <= Transmit_Data(0);
                  end if;
              -- Capture Data on even Count
              elsif(transfer_start = '1' and Count(0) = '0' ) then
                  Serial_Dout <= Shift_Reg(0);
              -- Shift Data on odd Count
              elsif(transfer_start = '1' and Count(0) = '1' and
                      Count_trigger_pulse = '1') then
                  Shift_Reg   <= Shift_Reg
                                 (1 to C_NUM_TRANSFER_BITS -1) & Serial_Din;
              end if;

          -- below mode is slave mode logic for SPI
          elsif(Mst_N_Slv = '0') then
              if(Loading_SR_Reg_int = '1' or spisel_pulse = '1') then
                  if(LSB_first = '1') then
                      for i in 0 to C_NUM_TRANSFER_BITS-1 loop
                          Shift_Reg(i) <= Transmit_Data
                                          (C_NUM_TRANSFER_BITS-1-i);
                      end loop;
                      Serial_Dout <= Transmit_Data(C_NUM_TRANSFER_BITS-1);
                  else
                      Shift_Reg   <= Transmit_Data;
                      Serial_Dout <= Transmit_Data(0);
                  end if;
              elsif (transfer_start = '1') then
                  if((CPOL = '0' and CPHA = '0') or
                      (CPOL = '1' and CPHA = '1')) then
                      if(rising_edge_sck_i = '1') then
                          rx_shft_reg_s   <= rx_shft_reg_s(1 to
                                         C_NUM_TRANSFER_BITS -1) & Serial_Din;
                          Shift_Reg <= Shift_Reg(1 to
                                         C_NUM_TRANSFER_BITS -1) & Serial_Din;
                      elsif(falling_edge_sck_i = '1') then
                          Serial_Dout <= Shift_Reg(0);
                      end if;
                  elsif((CPOL = '0' and CPHA = '1') or
                        (CPOL = '1' and CPHA = '0')) then
                      if(falling_edge_sck_i = '1') then
                          rx_shft_reg_s   <= rx_shft_reg_s(1 to
                                         C_NUM_TRANSFER_BITS -1) & Serial_Din;
                          Shift_Reg <= Shift_Reg(1 to
                                         C_NUM_TRANSFER_BITS -1) & Serial_Din;
                      elsif(rising_edge_sck_i = '1') then
                          Serial_Dout <= Shift_Reg(0);
                      end if;
                  end if;
              end if;
          end if;
      end if;
  end process CAPTURE_AND_SHIFT_PROCESS;
-----
end generate OTHER_RATIO_GENERATE;

-------------------------------------------------------------------------------
-- RATIO_OF_2_GENERATE : Logic to be used when C_SCK_RATIO is equal to 2
------------------------
RATIO_OF_2_GENERATE: if(C_SCK_RATIO = 2) generate
--------------------
begin
-----
-------------------------------------------------------------------------------
-- SCK_CYCLE_COUNT_PROCESS : Counts number of trigger pulses provided. Used for
--                           controlling the number of bits to be transfered
--                           based on generic C_NUM_TRANSFER_BITS
----------------------------
  SCK_CYCLE_COUNT_PROCESS: process(Bus2IP_Clk)
  begin
      if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          if(Reset = RESET_ACTIVE or transfer_start_d1 = '0' or
                                                          Mst_N_Slv = '0') then
              Count <= (others => '0');
          elsif (Count(COUNT_WIDTH) = '0') then
              Count <=  Count + 1;
          end if;
      end if;
  end process SCK_CYCLE_COUNT_PROCESS;

-------------------------------------------------------------------------------
-- SCK_SET_RESET_PROCESS : Sync set/reset toggle flip flop controlled by
--                         transfer_start signal
--------------------------
  SCK_SET_RESET_PROCESS: process(Bus2IP_Clk)
  begin
      if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          if(Reset = RESET_ACTIVE or Sync_Reset = '1') then
              sck_o_int <= '0';
          elsif(Sync_Set = '1') then
              sck_o_int <= '1';
          elsif (transfer_start = '1') then
              sck_o_int <= (not sck_o_int) xor Count(COUNT_WIDTH);
          end if;
      end if;
  end process SCK_SET_RESET_PROCESS;
-------------------------------------

--   CAPT_RX_FE_MODE_00_11: The below logic is to capture data for SPI mode of
--------------------------- 00 and 11.
  -- Generate a falling edge pulse from the serial clock. Use this to
  -- capture the incoming serial data into a shift register.
  CAPT_RX_FE_MODE_00_11 : process(Bus2IP_Clk)
  begin
    if(Bus2IP_Clk'event and Bus2IP_Clk = '0') then
          sck_d1 <= sck_o_int;
          sck_d2 <= sck_d1;
          if (sck_fe = '1') then
             rx_shft_reg_mode_0011 <= rx_shft_reg_mode_0011
                                        (1 to (C_NUM_TRANSFER_BITS-1)) & MISO_I;
          end if;
      end if;
  end process CAPT_RX_FE_MODE_00_11;

  -- Falling egde pulse
  sck_fe <= sck_d2 and not sck_d1;
  --
--   CAPT_RX_FE_MODE_01_10: the below logic captures data in SPI 01 or 10 mode.
---------------------------
  CAPT_RX_FE_MODE_01_10: process(Bus2IP_Clk)
  begin
      if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          sck_d11 <= sck_o_in;
          sck_d21 <= sck_d11;
          if(CPOL = '1' and CPHA = '0') then
               if (sck_d1 = '1' and transfer_start = '1') then
                        rx_shft_reg_mode_0110 <= rx_shft_reg_mode_0110
                                        (1 to (C_NUM_TRANSFER_BITS-1)) & MISO_I;
                end if;
          elsif(CPOL = '0' and CPHA = '1') then
               if (sck_fe1 = '0' and transfer_start = '1') then
                        rx_shft_reg_mode_0110 <= rx_shft_reg_mode_0110
                                        (1 to (C_NUM_TRANSFER_BITS-1)) & MISO_I;
               end if;
          end if;
      end if;
  end process CAPT_RX_FE_MODE_01_10;

  sck_fe1 <= (not sck_d11) and sck_d21;

-------------------------------------------------------------------------------
-- CAPTURE_AND_SHIFT_PROCESS : This logic essentially controls the entire
--                             capture and shift operation for serial data in
------------------------------ master SPI mode only
  CAPTURE_AND_SHIFT_PROCESS: process(Bus2IP_Clk)
  begin
      if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          if(Reset = RESET_ACTIVE) then
              Shift_Reg(0) <= '0';
              Shift_Reg(1) <= '1';
              Shift_Reg(2 to C_NUM_TRANSFER_BITS -1) <= (others => '0');
              Serial_Dout  <= '1';
          elsif(Mst_N_Slv = '1') then
              if(Loading_SR_Reg_int = '1') then
                  if(LSB_first = '1') then
                      for i in 0 to C_NUM_TRANSFER_BITS-1 loop
                         Shift_Reg(i) <= Transmit_Data
                                         (C_NUM_TRANSFER_BITS-1-i);
                      end loop;
                      Serial_Dout <= Transmit_Data(C_NUM_TRANSFER_BITS-1);
                  else
                      Shift_Reg   <= Transmit_Data;
                      Serial_Dout <= Transmit_Data(0);
                  end if;
              elsif(transfer_start = '1' and Count(0) = '0' and
                  Count(COUNT_WIDTH) = '0') then -- Shift Data on even
                  Serial_Dout <= Shift_Reg(0);
                elsif(transfer_start = '1' and Count(0) = '1'and
                  Count(COUNT_WIDTH) = '0') then -- Capture Data on odd
                  if(Loop_mode = '1') then       -- Loop mode
                      Shift_Reg   <= Shift_Reg(1 to
                                     C_NUM_TRANSFER_BITS -1) & Serial_Dout;
                  else
                      Shift_Reg   <= Shift_Reg(1 to
                                     C_NUM_TRANSFER_BITS -1) & MISO_I;
                  end if;
              end if;
          elsif(Mst_N_Slv = '0') then
              -- Added to have consistent default value after reset
              if(Loading_SR_Reg_int = '1' or spisel_pulse = '1') then
                  Shift_Reg   <= (others => '0');
                  Serial_Dout <= '0';
              end if;
          end if;
      end if;
  end process CAPTURE_AND_SHIFT_PROCESS;
-----
end generate RATIO_OF_2_GENERATE;

-------------------------------------------------------------------------------
-- SCK_SET_GEN_PROCESS : Generate SET control for SCK_O
------------------------
SCK_SET_GEN_PROCESS: process(CPOL,CPHA,transfer_start_pulse)
begin
    if(transfer_start_pulse = '1') then
        Sync_Set <= (CPOL xor CPHA);
    else
        Sync_Set <= '0';
    end if;
end process SCK_SET_GEN_PROCESS;

-------------------------------------------------------------------------------
-- SCK_RESET_GEN_PROCESS : Generate SET control for SCK_O
--------------------------
SCK_RESET_GEN_PROCESS: process(CPOL,CPHA,transfer_start_pulse)
begin
    if(transfer_start_pulse = '1') then
        Sync_Reset <= not(CPOL xor CPHA);
    else
        Sync_Reset <= '0';
    end if;
end process SCK_RESET_GEN_PROCESS;

-------------------------------------------------------------------------------
-- RATIO_NOT_EQUAL_4_GENERATE : Logic to be used when C_SCK_RATIO is not equal
--                              to 4
-------------------------------
RATIO_NOT_EQUAL_4_GENERATE: if(C_SCK_RATIO /= 4) generate
begin
-----
-------------------------------------------------------------------------------
-- SCK_O_SELECT_PROCESS : Select the idle state (CPOL bit) when not transfering
--                        data else select the clock for slave device
-------------------------
  SCK_O_SELECT_PROCESS: process(sck_o_int,CPOL,transfer_start,
                                transfer_start_d1,Count(COUNT_WIDTH))
  begin
      if(transfer_start = '1' and transfer_start_d1 = '1' and
          Count(COUNT_WIDTH) = '0') then
          sck_o_in <= sck_o_int;
      else
          sck_o_in <= CPOL;
      end if;
  end process SCK_O_SELECT_PROCESS;

-------------------------------------------------------------------------------
-- SCK_O_FINAL_PROCESS : Register the final SCK_O
------------------------
  SCK_O_FINAL_PROCESS: process(Bus2IP_Clk)
  begin
      if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          -- If Reset or slave Mode. Prevents SCK_O to be generated in slave
          if(Reset = RESET_ACTIVE or Mst_N_Slv = '0') then
              SCK_O <= '0';
          else
              SCK_O <= sck_o_in;
          end if;
      end if;
  end process SCK_O_FINAL_PROCESS;
-----
end generate RATIO_NOT_EQUAL_4_GENERATE;


-------------------------------------------------------------------------------
-- RATIO_OF_4_GENERATE : Logic to be used when C_SCK_RATIO is equal to 4
------------------------
RATIO_OF_4_GENERATE: if(C_SCK_RATIO = 4) generate
begin
-----
-------------------------------------------------------------------------------
-- SCK_O_FINAL_PROCESS : Select the idle state (CPOL bit) when not transfering
--                       data else select the clock for slave device
------------------------
-- A work around to reduce one clock cycle for sck_o generation. This would
-- allow for proper shifting of data bits into the slave device.
-- Removing the final stage F/F. Disadvantage of not registering final output
-------------------------------------------------------------------------------
   SCK_O_FINAL_PROCESS: process(Mst_N_Slv,sck_o_int,CPOL,transfer_start,
                                transfer_start_d1,Count(COUNT_WIDTH))
   begin
    if(Mst_N_Slv = '1' and transfer_start = '1' and transfer_start_d1 = '1' and
         Count(COUNT_WIDTH) = '0') then
         SCK_O_1 <= sck_o_int;
    else
         SCK_O_1 <= CPOL and Mst_N_Slv;
    end if;
   end process SCK_O_FINAL_PROCESS;

   ----------------------------------------------------------------------------
   -- SCK_RATIO_4_REG_PROCESS : The SCK is registered in SCK RATIO = 4 mode
   ----------------------------------------------------------------------------
   SCK_RATIO_4_REG_PROCESS: process(Bus2IP_Clk)
   begin
        if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
          -- If Reset or slave Mode. Prevents SCK_O to be generated in slave
           if(Reset = RESET_ACTIVE  or Mst_N_Slv = '0') then
    		SCK_O <= '0';
           else
    		SCK_O <= SCK_O_1;
           end if;
        end if;
   end process SCK_RATIO_4_REG_PROCESS;

end generate RATIO_OF_4_GENERATE;

-------------------------------------------------------------------------------
-- LOADING_FIRST_ELEMENT_PROCESS : Combinatorial process to generate flag
--                                 when loading first data element in shift
--                                 register from transmit register/fifo
----------------------------------
LOADING_FIRST_ELEMENT_PROCESS: process(Reset, SPI_En,Mst_N_Slv,
                                       SS_Asserted,SS_Asserted_1dly,
                                       SR_3_MODF,transfer_start_pulse)
begin
    if(Reset = RESET_ACTIVE) then
        Loading_SR_Reg_int <= '0';              --Clear flag
    elsif(SPI_En                 = '1'   and    --Enabled
          (
           (Mst_N_Slv              = '1'   and  --Master configuration
            SS_Asserted            = '1'   and
            SS_Asserted_1dly       = '0'   and
            SR_3_MODF              = '0'
           ) or
           (Mst_N_Slv              = '0'   and  --Slave configuration
            (transfer_start_pulse = '1')
           )
          )
         )then
        Loading_SR_Reg_int <= '1';               --Set flag
    else
        Loading_SR_Reg_int <= '0';               --Clear flag
    end if;
end process LOADING_FIRST_ELEMENT_PROCESS;

-------------------------------------------------------------------------------
-- SELECT_OUT_PROCESS : This process sets SS active-low, one-hot encoded select
--                      bit. Changing SS is premitted during a transfer by
--                      hardware, but is to be prevented by software. In Auto
--                      mode SS_O reflects value of Slave_Select_Reg only
--                      when transfer is in progress, otherwise is SS_O is held
--                      high
-----------------------
SELECT_OUT_PROCESS: process(Bus2IP_Clk)
begin
    if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
       if(Reset = RESET_ACTIVE) then
           SS_O                   <= (others => '1');
           SS_Asserted            <= '0';
           SS_Asserted_1dly       <= '0';
       elsif(transfer_start = '0') then    -- Tranfer not in progress
           if(Manual_SS_mode = '0') then   -- Auto SS assert
               SS_O   <= (others => '1');
           else
               for i in 0 to C_NUM_SS_BITS-1 loop
                   SS_O(i) <= Slave_Select_Reg(C_NUM_SS_BITS-1-i);
               end loop;
           end if;
           SS_Asserted       <= '0';
           SS_Asserted_1dly  <= '0';
       else
           for i in 0 to C_NUM_SS_BITS-1 loop
               SS_O(i) <= Slave_Select_Reg(C_NUM_SS_BITS-1-i);
           end loop;
           SS_Asserted       <= '1';
           SS_Asserted_1dly  <= SS_Asserted;
       end if;
    end if;
end process SELECT_OUT_PROCESS;

-------------------------------------------------------------------------------
-- MODF_STROBE_PROCESS : Strobe MODF signal when master is addressed as slave
------------------------
MODF_STROBE_PROCESS: process(Bus2IP_Clk)
begin
    if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
       if(Reset = RESET_ACTIVE or SPISEL_sync = '1') then
           MODF_strobe       <= '0';
           MODF_strobe_int   <= '0';
           Allow_MODF_Strobe <= '1';
       elsif(Mst_N_Slv = '1' and --In Master mode
             SPISEL_sync = '0' and Allow_MODF_Strobe = '1') then
           MODF_strobe       <= '1';
           MODF_strobe_int   <= '1';
           Allow_MODF_Strobe <= '0';
       else
           MODF_strobe       <= '0';
           MODF_strobe_int   <= '0';
       end if;
    end if;
end process MODF_STROBE_PROCESS;

-------------------------------------------------------------------------------
-- SLAVE_MODF_STROBE_PROCESS : Strobe MODF signal when slave is addressed
--                             but not enabled.
------------------------------
SLAVE_MODF_STROBE_PROCESS: process(Bus2IP_Clk)
begin
    if(Bus2IP_Clk'event and Bus2IP_Clk = '1') then
       if(Reset = RESET_ACTIVE or SPISEL_sync = '1') then
           Slave_MODF_strobe      <= '0';
           Allow_Slave_MODF_Strobe<= '1';
       elsif(Mst_N_Slv   = '0' and    --In Slave mode
             SPI_En      = '0' and    --but not enabled
             SPISEL_sync      = '0' and Allow_Slave_MODF_Strobe = '1') then
           Slave_MODF_strobe       <= '1';
           Allow_Slave_MODF_Strobe <= '0';
       else
           Slave_MODF_strobe       <= '0';
       end if;
    end if;
end process SLAVE_MODF_STROBE_PROCESS;
---------------------xxx------------------------------------------------------
end imp;