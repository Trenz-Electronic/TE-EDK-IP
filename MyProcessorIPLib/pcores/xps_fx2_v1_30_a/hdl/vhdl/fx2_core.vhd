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

-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity fx2_core is
  generic (
    C_TX_FIFO_KBYTE         : integer := 32;
    C_RX_FIFO_KBYTE         : integer := 0;
	 C_USE_ADDR_FIFO         : integer := 0;
	 C_TX_RDY_ALMOST_FULL : integer := 1;
	 C_TX_FIFO_CLK_180         : integer := 0
    );
  port (
    SYS_Clk              : in  std_logic;
    SYS_Rst              : in  std_logic;

	 Reg_in_0 				 : in std_logic_vector(0 to 31);
	 Reg_in_1 				 : in std_logic_vector(0 to 31);
	 Reg_out_0 				 : out std_logic_vector(0 to 31);

    Interrupt            : out std_logic_VECTOR(0 to 7);

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
	                    
    ChipScope        : out std_logic_vector(0 to 31) := (others => '0')
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
-- Signals declaration
------------------------------------------

	signal timeout_cnt			:  integer range 0 to 65536	:= 0;	--counter	for	transfers
	signal pktend_timeout		:  integer range 0 to 65535	:= 0;	--counter	for	transfers
	
-- TX FIFO signals
  signal TX_FIFO_RDY_reg         : std_logic := '0';
  signal tx_fifo_out_en          : std_logic := '0';
  signal tx_fifo_out_en_i        : std_logic := '0';
  signal tx_fifo_full            : std_logic := '0';
  signal tx_fifo_almostfull      : std_logic := '0';
  signal tx_fifo_empty           : std_logic := '0';
  signal tx_fifo_overflow			: std_logic := '0';
  signal tx_fifo_underflow			: std_logic := '0';
  signal tx_fifo_prog_empty       : std_logic := '0';
  signal tx_fifo_rst             : std_logic := '0';
  signal tx_fifo_reset           : std_logic := '0';
  signal tx_fifo_valid				: std_logic := '0';

  signal tx_fifo_count           : std_logic_VECTOR(TX_FIFO_COUNT_BITS-1 downto 0);
  signal tx_fifo_threshold        : std_logic_VECTOR(TX_FIFO_COUNT_BITS-1 downto 0);

-- TX ADDRESS FIFO signals
  signal addr_fifo_read	         : std_logic := '0';
	signal addr_fifo_cnt				:  integer range 0 to 4	:= 0;	--counter	for	transfers


-- RX FIFO signals
	signal  rx_fifo_out_en          : std_logic := '0';
	signal  rx_fifo_out_valid       : std_logic := '0';
  signal rx_fifo_in_en          : std_logic := '0';
  signal rx_fifo_in_en_d          : std_logic := '0';
  signal rx_fifo_full            : std_logic := '0';
  signal rx_fifo_almost_full     : std_logic := '0';
  signal rx_fifo_empty           : std_logic := '0';
  signal rx_fifo_prog_full       : std_logic := '0';
  signal rx_fifo_underflow       : std_logic := '0';
  signal rx_fifo_rst             : std_logic := '0';
  signal rx_fifo_reset           : std_logic := '0';
  signal rx_fifo_count           : std_logic_VECTOR(RX_FIFO_COUNT_BITS-1 downto 0);
  signal rx_fifo_threshold        : std_logic_VECTOR(RX_FIFO_COUNT_BITS-1 downto 0);

--FX2 signals
  signal fifo2fx2_state       : std_logic_vector(1 downto 0) := "00";
  signal fx2tofifo_state       : std_logic_vector(1 downto 0) := "00";
  signal usb_rnw              : std_logic := '0'; --read not write 1=FX2 writes FPGA
  signal USB_tx_empty         : std_logic := '0';  -- FX2 transmit fifo empty
  signal USB_tx_full          : std_logic := '0';  -- FX2 transmit fifo full
  signal USB_rx_empty         : std_logic := '0';  -- FX2 receive fifo empty
  
  signal USB_SLWR_i           : std_logic := '0';  -- write to FX2 fifo en
  signal USB_SLRD_i           : std_logic := '0';  -- read from FX2 fifo en
  signal USB_READ             : std_logic := '0';  -- read from FX2 fifo en  
  signal USB_IFCLK_180        : std_logic := '0';  -- negated IFCLK 
  signal USB_TXCLK      	  : std_logic := '0';  -- TX_FIFO clock 
  signal USB_PKTEND_i           : std_logic := '0';  --packet end
  signal USB_FIFOADR_f        : std_logic_vector(1 downto 0) := "10";
  signal REG_FIFOADR          : std_logic_vector(1 downto 0) := "10";
  signal RX_FIFO_DOUT_i				: std_logic_vector(31 downto 0)  := (others => '0');
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
	almost_full: OUT std_logic;
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


------------------------------------------
-- Implementation
------------------------------------------

begin

------------------------------------------
-- Signal connections
------------------------------------------

	--Chipscope trigger
	ChipScope <= USB_FLAGA & USB_FLAGB & USB_FLAGC & USB_FLAGD
					& TX_FIFO_VLD & tx_fifo_out_en & tx_fifo_empty & tx_fifo_full
--					& rx_fifo_in_en & rx_fifo_out_en & rx_fifo_empty & rx_fifo_almost_full
					& REG_FIFOADR & fifo2fx2_state
               & USB_SLRD_i & USB_SLWR_i & USB_PKTEND_i & usb_rnw
--					& RX_FIFO_DOUT_i(31 downto 16);
               & tx_fifo_underflow & tx_fifo_valid & rx_fifo_out_valid  & "00000"
--					& tx_fifo_count(12 downto 0); --TX_FIFO_COUNT
					& tx_fifo_count(7 downto 0); --8 bits
--					& USB_FD_I; --8 bits

	--INTERRUPT signals connection	
	Interrupt <= "0000" & rx_fifo_underflow & tx_fifo_overflow & rx_fifo_prog_full & tx_fifo_prog_empty;

	--FIFO signals connection
	tx_fifo_reset <= SYS_Rst or tx_fifo_rst;
	rx_fifo_reset <= SYS_Rst or rx_fifo_rst;
  
  RDY_IS_FULL:
   if C_TX_RDY_ALMOST_FULL = 0 generate
      begin
			TX_FIFO_RDY <= '0' when ((tx_fifo_reset = '1') or (tx_fifo_full = '1')) else TX_FIFO_RDY_reg;
   end generate;

  RDY_IS_ALMOST_FULL:
   if C_TX_RDY_ALMOST_FULL = 1 generate
      begin
			TX_FIFO_RDY <= '0' when ((tx_fifo_reset = '1') or (tx_fifo_almostfull = '1')) else TX_FIFO_RDY_reg;
   end generate;
	  
  RX_FIFO_VLD <= rx_fifo_out_valid;
  rx_fifo_out_en <= RX_FIFO_RDY;
 
  --FX2 SIGNAL ROUTING
  USB_IFCLK_180 <= not USB_IFCLK;
	USB_TXCLK <= not USB_IFCLK when C_TX_FIFO_CLK_180 = 1 else USB_IFCLK;
	tx_fifo_out_en <= '0' when (tx_fifo_empty = '1' or USB_tx_full = '1') else tx_fifo_out_en_i; 
	
	USB_SLWR <= tx_fifo_valid;
  USB_rx_empty <= USB_FLAGD;
  USB_tx_full <= USB_FLAGB;
  USB_tx_empty <= USB_FLAGC;
--  USB_SLWR <= USB_SLWR_i; --FX2 fifo write enable 
	USB_PKTEND <= USB_PKTEND_i;
	RX_FIFO_DOUT <= RX_FIFO_DOUT_i;
	
   --toggle IO buffer (1=INPUT)
	USB_FD_T <= usb_rnw;
   --toggle FX2 IO buffer (1=DRIVER ENABLE)
	USB_SLOE <= usb_rnw;
	
------------------------------------------
-- Register slicing
------------------------------------------
      tx_fifo_rst <= Reg_in_0(31);	--signal to reset fifo
		rx_fifo_rst <= Reg_in_0(30);	--signal to reset fifo
		TX_FIFO_RDY_reg <= not Reg_in_0(29);	--signal to disable external fifo port
		REG_FIFOADR <= Reg_in_0(26 to 27);	--signal to select EP addr
		pktend_timeout <= CONV_INTEGER(Reg_in_0(0 to 15));	--sets packet end timeout value
		
		tx_fifo_threshold(TX_FIFO_COUNT_BITS-1 downto 0) <= Reg_in_1(32-TX_FIFO_COUNT_BITS to 31);	--signal to set fifo threshold
		
		Reg_out_0(32-TX_FIFO_COUNT_BITS to 31) <= tx_fifo_count(TX_FIFO_COUNT_BITS-1 downto 0);
--		Reg_out_0(19) <= tx_fifo_prog_empty;
		Reg_out_0(18) <= tx_fifo_overflow;
		Reg_out_0(17) <= tx_fifo_full;
		Reg_out_0(16) <= tx_fifo_empty;
		Reg_out_0(16-RX_FIFO_COUNT_BITS to 15) <= rx_fifo_count(RX_FIFO_COUNT_BITS-1 downto 0);
		Reg_out_0(3) <= rx_fifo_prog_full;
		Reg_out_0(2) <= rx_fifo_underflow;
		Reg_out_0(1) <= rx_fifo_full;
		Reg_out_0(0) <= rx_fifo_empty;

------------------------------------------
-- Processes
------------------------------------------
process (USB_IFCLK_180)
begin
	if (USB_IFCLK_180'event and USB_IFCLK_180 = '1') then --falling edge
			  rx_fifo_in_en_d <= USB_READ;
	end if;
end process;
rx_fifo_in_en <= rx_fifo_in_en_d and (not USB_rx_empty);

process (USB_IFCLK)
begin
	if (USB_IFCLK'event and USB_IFCLK = '1') then --rising edge
		USB_SLRD <= USB_READ  and (not USB_rx_empty);
	end if;
end process;

------------------------------------------
-- FIFO threshold 
------------------------------------------
TX_FIFO_PROG_FULL_DETECT : process (SYS_Clk)
begin
	if (SYS_Clk'event and SYS_Clk	=	'1') then 
		if (tx_fifo_reset = '1') then --reset
			tx_fifo_prog_empty <= '1';
		elsif (tx_fifo_count <= tx_fifo_threshold) then --under threshold
			tx_fifo_prog_empty <= '1';
		else
			tx_fifo_prog_empty <= '0';
		end	if;
	end	if;
end	process	TX_FIFO_PROG_FULL_DETECT;

RX_FIFO_PROG_FULL_DETECT : process (SYS_Clk)
begin
	if (SYS_Clk'event and SYS_Clk	=	'1') then 
		if (tx_fifo_reset = '1') then --reset
			rx_fifo_prog_full <= '0';
		elsif (rx_fifo_count >= rx_fifo_threshold) then --over threshold
			rx_fifo_prog_full <= '1';
		else
			rx_fifo_prog_full <= '0';
		end	if;
	end	if;
end	process	RX_FIFO_PROG_FULL_DETECT;


ADRFIFO_COUNT_PROCESS: process(tx_fifo_reset, tx_fifo_empty, USB_IFCLK)
begin
	if (tx_fifo_reset = '1' or tx_fifo_empty = '1') then
		addr_fifo_read <= '0';
		addr_fifo_cnt <= 0;
	elsif (USB_IFCLK'event and USB_IFCLK = '1') then --rising edge
		addr_fifo_read <= '0';
		if (USB_SLWR_i = '1') then
			addr_fifo_cnt <= addr_fifo_cnt+1;
			if (addr_fifo_cnt = 3) then
				addr_fifo_cnt <= 0;
				addr_fifo_read <= '1';
			end if;
		end if;
	end if;
end process	ADRFIFO_COUNT_PROCESS;
------------------------------------------
-- fifo to FX2 writing
------------------------------------------
-->Pisanje v fifo:
--> 0. Nato pocakas, da je fifo prazen - takrat je FLAGC = 1;
-->    Sledi pisanje v fifo:
--> 1. v zacetnem stanju je SLWR = 0, SLOE = 0
--> 2. ko gre IFCLK iz 1 -> 0, das na FD0-15 prvi potatek, SLWR = 1;
--> 3. pocakas na naslednji IFCLK 1 -> 0; das SLWR = 0;
--> 4. pocakas na IFCLK iz 1 -> 0, das na FD0-15 naslednji potatek, SLWR = 1;
--> 5. spet pocakas na naslednji IFCLK 1 -> 0; das SLWR = 0;
--> 6. ponavljas tocko 4,5, dokler ne gre FLAGB na 1 (fifo poln), takrat gres nazaj na tocko 0.

FIFO2FX2_WRITE_PROCESS: process (SYS_Rst, USB_IFCLK)
begin
	if (SYS_Rst = '1') then
		fifo2fx2_state <= "00"; --to IDLE state
		USB_SLWR_i <= '0'; -- write = 0
		tx_fifo_out_en_i <= '0'; --disable fifo
		usb_rnw <= '0';
  elsif (USB_IFCLK'event and USB_IFCLK = '1') then --rising edge
      case fifo2fx2_state is

        when "00" => --IDLE
			usb_rnw <= '0'; --write data
			USB_SLWR_i <= '0'; -- write = 0
			 if (USB_rx_empty = '0') then
				usb_rnw <= '1'; --read data
          elsif (tx_fifo_empty = '0' and
                  --USB_tx_empty = '1' and --FX2 FIFO EMPTY
						USB_tx_full = '0' and --FX2 FIFO not FULL
                  USB_rx_empty = '1') then --podatki v fifo
              fifo2fx2_state <= "01"; --next state
              tx_fifo_out_en_i <= '1'; --fire fifo
          end if;

        when "01" => --WRITE
			usb_rnw <= '0'; --write data
			if (tx_fifo_empty = '1') then --last word in a FIFO
            tx_fifo_out_en_i <= '0'; --disable fifo
				USB_SLWR_i <= '0'; -- write = 0
--				fifo2fx2_state <= "11"; --to LAST state
				fifo2fx2_state <= "00"; --to IDLE state
			elsif (USB_rx_empty = '0' or --FX2 rx fifo empty
				USB_tx_full = '1') then--FX2 tx fifo full
				--2 bytes left in fifo register
            tx_fifo_out_en_i <= '0'; --disable fifo
            USB_SLWR_i <= '0'; -- write = 0
            fifo2fx2_state <= "10"; --to WAIT state
          else --transfer
				USB_SLWR_i <= '1';
				tx_fifo_out_en_i <= '1'; --enable fifo read
          end if;

			when "10" => --WAIT
				usb_rnw <= '0'; --write data
				USB_SLWR_i <= '0'; -- write = 0
				if (USB_rx_empty = '0') then
					usb_rnw <= '1'; --read data
				elsif (USB_tx_full = '0') then --FX2 FIFO not FULL
					--consume the previous byte
					fifo2fx2_state <= "01"; --to WRITE state	
				end if;
        when others => null; --DO NOTHING
      end case;
  end if;
end process FIFO2FX2_WRITE_PROCESS;

------------------------------------------
-- FX2 to fifo writing
------------------------------------------
FX2toFIFO_WRITE_PROCESS: process (SYS_Rst, USB_IFCLK)
begin
	if (SYS_Rst = '1') then
		fx2tofifo_state <= "00"; --to IDLE state
		USB_READ <= '0'; -- read = 0
	elsif (USB_IFCLK'event and USB_IFCLK = '1') then --rising edge
		case fx2tofifo_state is

			when "00" => --IDLE
				USB_READ <= '0'; -- read = 0
				if (usb_rnw = '1' and 
						rx_fifo_almost_full = '0' and 
						USB_rx_empty = '0') then
					USB_READ <= '1'; -- read = 1
					fx2tofifo_state <= "01"; --next state
				end if;
				
			when "01" => --WRITE
				USB_READ <= '1'; -- read = 1
				if (rx_fifo_almost_full = '1' or USB_rx_empty = '1') then
					USB_READ <= '0'; -- read = 0
					fx2tofifo_state <= "00"; --next state
				end if;
				
        when others => null; --DO NOTHING
      end case;
	end if;
end process FX2toFIFO_WRITE_PROCESS;

------------------------------------------
-- Packet end (PKTEND) signal generation
------------------------------------------

PKTEND_GENERATION_PROCESS: process (USB_IFCLK)
begin
	if (USB_IFCLK'event and USB_IFCLK = '1') then --rising edge
		USB_PKTEND_i <= '0'; --reset flag
		if (SYS_Rst = '1' or USB_tx_empty = '1' or tx_fifo_empty = '0' or usb_rnw = '1') then
			timeout_cnt <= 0; --reset counter
		elsif (timeout_cnt < pktend_timeout) then --counting
			timeout_cnt <= timeout_cnt + 1;
		elsif (timeout_cnt = pktend_timeout) then --timeout reached
			timeout_cnt <= timeout_cnt + 1;
			if (USB_tx_full = '0') then --if fifo is not full
				USB_PKTEND_i <= '1'; --commence packet
			end if;
		end if;
	end if;
end process PKTEND_GENERATION_PROCESS;


------------------------------------------
-- Port Maps
------------------------------------------

TX_FIFI : tx_fifo
	port map(
    din => TX_FIFO_DIN,
    rd_clk => USB_TXCLK,
    rd_en => tx_fifo_out_en,
    rst => tx_fifo_reset,
    wr_clk => TX_FIFO_Clk,
    wr_en => TX_FIFO_VLD,
    dout => USB_FD_O,
    empty => tx_fifo_empty,
    full => tx_fifo_full,
	 almost_full => tx_fifo_almostfull,
    overflow => tx_fifo_overflow,
	 valid => tx_fifo_valid,
	 underflow => tx_fifo_underflow,
	 wr_data_count => tx_fifo_count
	);

TX_FIFI_ADDR_GEN : 
if C_USE_ADDR_FIFO=1
generate
	begin 
	TX_FIFI_ADDR : tx_addr_fifo
		port map (
			din => REG_FIFOADR,
			rd_clk => USB_IFCLK,
			rd_en => addr_fifo_read,
			rst => tx_fifo_reset,
			wr_clk => TX_FIFO_Clk,
			wr_en => TX_FIFO_VLD,
			dout => USB_FIFOADR_f,
			empty => open,
			full => open);
end generate;
--FIFOADR mux
USB_FIFOADR <= "11" when (usb_rnw = '1') else  --reading EP8
					USB_FIFOADR_f when (C_USE_ADDR_FIFO=1) --using addr fifo
					else REG_FIFOADR; --not using addr fifo

RX_FIFO_GEN : 
if C_RX_FIFO_KBYTE>0
generate
	begin 
	rx_fifo_threshold(RX_FIFO_COUNT_BITS-1 downto 0) <= Reg_in_1(16-RX_FIFO_COUNT_BITS to 15);	--signal to set fifo threshold
	
	RX_FIFI : rx_fifo
		port map (
			din => USB_FD_I,
			rd_clk => TX_FIFO_Clk,
			rd_en => rx_fifo_out_en,
			rst => rx_fifo_reset,
			wr_clk => USB_IFCLK_180,
			wr_en => rx_fifo_in_en,
			almost_full => rx_fifo_almost_full,
			dout => RX_FIFO_DOUT_i,
			empty => rx_fifo_empty,
			full => rx_fifo_full,
			overflow => open,
			valid => rx_fifo_out_valid,
			rd_data_count => rx_fifo_count,
			underflow => rx_fifo_underflow);
end generate;

end IMP;
