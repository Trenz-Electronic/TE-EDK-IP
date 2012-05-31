-- "r" test always failed
-- "w" test 20.8 MB/s
----------------------------------------------------------------------------------
-- Company: Trenz Electronic GmbH
-- Engineer: Alexander Kinko
-- 
-- Create Date:    20:29:43 08/25/2011 
-- Design Name:  
-- Module Name:    fx2_engine - Behavioral 
-- Project Name: FX2 core
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
--      USB_IFCLK                   -- FX2 IF clock (48MHz)
--      USB_SLRD                    -- read from FX2 fifo en 
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
-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------
entity fx2_engine is
	generic (
		TX_FIFO_COUNT_BITS			: integer := 13;
		RX_FIFO_COUNT_BITS			: integer := 9;
		C_TX_FIFO_KBYTE         : integer := 32;
    C_RX_FIFO_KBYTE         : integer := 0;
		C_USE_ADDR_FIFO         : integer := 0;
		C_TX_RDY_ALMOST_FULL 		: integer := 1;
		C_TX_FIFO_CLK_180       : integer := 0;
		C_USE_CRITICAL					: integer := 0
	);
  port (
    SYS_Clk              		: in  std_logic;
    SYS_Rst              		: in  std_logic;

		Reg_in_0 				 				: in  std_logic_vector(0 to 31);
		Reg_in_1 				 				: in  std_logic_vector(0 to 31);
		Reg_out_0 				 			: out std_logic_vector(0 to 31);

    Interrupt            		: out std_logic_VECTOR(0 to 7);

    USB_IFCLK            		: in  std_logic;
		USB_RX_CLK							: in  std_logic;
    USB_SLRD             		: out std_logic;
    USB_SLWR             		: out std_logic;
    USB_FLAGA            		: in  std_logic;	-- Not used
    USB_FLAGB            		: in  std_logic;
    USB_FLAGC            		: in  std_logic;
		USB_FLAGD            		: in  std_logic;
		USB_SLOE             		: out std_logic;
		USB_PKTEND           		: out std_logic;
		USB_FIFOADR         		: out std_logic_vector(1 downto 0); --"00"=EP2,"01"=EP4,"10"=EP6,11"=EP8
    USB_FD_T             		: out std_logic_vector(7 downto 0) := (others => '1');
    USB_FD_O             		: out std_logic_vector(7 downto 0) := (others => '0');
    USB_FD_I             		: in  std_logic_vector(7 downto 0);
		
		tx_fifo_rd							: out std_logic;
		tx_fifo_data						: in  std_logic_vector(7 downto 0);
		tx_fifo_reset						: out std_logic;
		tx_fifo_full						: in  std_logic;
		tx_fifo_empty						: in	std_logic;
		tx_fifo_overflow				: in  std_logic;
		tx_fifo_count						: in	std_logic_vector(TX_FIFO_COUNT_BITS-1 downto 0);
		tx_fifo_valid						: in 	std_logic;
		
		tx_fifo_rdy							: out std_logic;
		
		tx_addr_fifo_rd					: out std_logic;
		tx_addr_fifo_data				: in  std_logic_vector(1 downto 0);
		tx_addr_fifo_reset			: out std_logic;

		rx_fifo_wr							: out	std_logic;
		rx_fifo_data						: out	std_logic_vector(7 downto 0);
		rx_fifo_reset						: out std_logic;
		rx_fifo_full						: in  std_logic;
		rx_fifo_empty						: in	std_logic;
		rx_fifo_almostfull			: in  std_logic;
		rx_fifo_underflow				: in  std_logic;
		rx_fifo_count						: in	std_logic_vector(RX_FIFO_COUNT_BITS-1 downto 0);
	                    
    ChipScope        				: out std_logic_vector(0 to 31) := (others => '0')
    );
end entity fx2_engine;
------------------------------------------------------------------------------
-- Architecture section
------------------------------------------------------------------------------
architecture rtl of fx2_engine is
-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
constant C_USB_SLOE_ENABLE_LEVEL	: std_logic := '1';
constant C_USB_SLOE_DISABLE_LEVEL	: std_logic := '0';
constant C_USB_SLRD_ACTIVE				: std_logic := '1';
constant C_USB_SLRD_PASSIVE				: std_logic := '0';
constant C_USB_SLWR_ACTIVE				: std_logic := '1';
constant C_USB_SLWR_PASSIVE				: std_logic := '0';

------------------------------------------
-- Signals declaration
------------------------------------------
-- Registers for all input signals
signal usb_tx_empty   : std_logic;  -- FX2 transmit fifo empty
signal usb_tx_full    : std_logic;  -- FX2 transmit fifo full
signal usb_rx_empty   : std_logic;  -- FX2 receive fifo empty
signal fd_i_reg				: std_logic_vector(7 downto 0);

-- Drivers for outputs
signal  fd_o_drv			: std_logic_vector(7 downto 0) := (others => '0');
signal  fd_t_drv			: std_logic_vector(7 downto 0) := (others => '1');
signal	slrd_drv			: std_logic;
signal	slwr_drv			: std_logic;
signal	sloe_drv			: std_logic;
signal	pktend_drv		: std_logic;
signal	fifoaddr_drv	: std_logic_vector(1 downto 0); --"00"=EP2,"01"=EP4,"10"=EP6,11"=EP8

-- FSM
type wr_state_type is (
	STATE_WR_INIT,
	STATE_WR,
	STATE_WR_REM,
	STATE_READ_1,
	STATE_READ_2
);
signal	wr_fsm_state	: wr_state_type;
	
signal addr_fifo_rd_cnt		: std_logic_vector(1 downto 0);

	-- Others
signal tx_fifo_rst        : std_logic := '0';
signal rx_fifo_rst        : std_logic := '0';
signal TX_FIFO_RDY_reg  	: std_logic := '0';
signal REG_FIFOADR      	: std_logic_vector(1 downto 0) := "10";
signal tx_fifo_threshold  : std_logic_VECTOR(TX_FIFO_COUNT_BITS-1 downto 0);
signal rx_fifo_threshold  : std_logic_VECTOR(RX_FIFO_COUNT_BITS-1 downto 0);
signal rx_fifo_prog_full  : std_logic := '0';
signal tx_fifo_prog_empty : std_logic := '0';
signal tx_fifo_reset_drv	: std_logic;
signal rx_fifo_reset_drv	: std_logic;
signal tx_fifo_read_req		: std_logic;
signal read_fsm_enable		: std_logic;
signal fd_t_bit						: std_logic;
signal last_write					: std_logic;
attribute box_type        : string;
attribute iob							: string;
------------------------------------------
-- Implementation
------------------------------------------
begin
------------------------------------------
-- Register slicing
------------------------------------------
	tx_fifo_rst 		<= Reg_in_0(31);	--signal to reset fifo
	rx_fifo_rst 		<= Reg_in_0(30);	--signal to reset fifo
	TX_FIFO_RDY_reg <= not Reg_in_0(29);	--signal to disable external fifo port
	REG_FIFOADR 		<= Reg_in_0(26 to 27);	--signal to select EP addr
	tx_fifo_threshold(TX_FIFO_COUNT_BITS-1 downto 0) <= Reg_in_1(32-TX_FIFO_COUNT_BITS to 31);	--signal to set fifo threshold
	rx_fifo_threshold(RX_FIFO_COUNT_BITS-1 downto 0) <= Reg_in_1(16-RX_FIFO_COUNT_BITS to 15);	--signal to set fifo threshold
	Reg_out_0(32-TX_FIFO_COUNT_BITS to 31) <= tx_fifo_count(TX_FIFO_COUNT_BITS-1 downto 0);
	--Reg_out_0(19) <= tx_fifo_prog_empty;
	Reg_out_0(18) 	<= tx_fifo_overflow;
	Reg_out_0(17) 	<= tx_fifo_full;
	Reg_out_0(16)	 	<= tx_fifo_empty;
	Reg_out_0(16-RX_FIFO_COUNT_BITS to 15) <= rx_fifo_count(RX_FIFO_COUNT_BITS-1 downto 0);
	Reg_out_0(3) 		<= rx_fifo_prog_full;
	Reg_out_0(2) 		<= rx_fifo_underflow;
	Reg_out_0(1) 		<= rx_fifo_full;
	Reg_out_0(0) 		<= rx_fifo_empty;
------------------------------------------
	--Chipscope trigger
	ChipScope <= 
	x"0000_000" &
	"0" &
	slwr_drv &	-- Write
	USB_FLAGB &	-- USB_TX_FULL
	USB_FLAGA;	-- Unknown
------------------------------------------
-- USB Inputs
------------------------------------------
process(USB_IFCLK,SYS_Rst)
begin
	if(SYS_Rst = '1')then
		usb_tx_empty	<= '1';
	elsif(USB_IFCLK = '1' and USB_IFCLK'event)then
		usb_tx_empty	<= USB_FLAGC;
	end if;
end process;
usb_rx_empty	<= USB_FLAGD;
usb_tx_full		<= USB_FLAGB;

process(USB_RX_CLK)
begin
	if(USB_RX_CLK = '1' and USB_RX_CLK'event)then
		fd_i_reg			<= USB_FD_I;
	end if;
end process;
------------------------------------------
-- USB Outputs
------------------------------------------
USB_SLRD			<= slrd_drv;
USB_SLWR 			<= tx_fifo_valid;
USB_SLOE			<= sloe_drv;
USB_PKTEND		<= pktend_drv;
USB_FIFOADR		<= fifoaddr_drv;
USB_FD_T			<= fd_t_drv;
USB_FD_O			<= fd_o_drv;
------------------------------------------
	-- Write FSM
------------------------------------------
	process(USB_IFCLK,SYS_Rst)
	begin
		if(SYS_Rst = '1')then
			wr_fsm_state			<= STATE_WR_INIT;
			tx_fifo_read_req	<= '0';
			read_fsm_enable		<= '0';	
			rx_fifo_wr				<= '0';
			rx_fifo_data			<= (others => '0');
			last_write 				<= '0';
		elsif(USB_IFCLK = '1' and USB_IFCLK'event)then
			case wr_fsm_state is
				when STATE_WR_INIT =>
					rx_fifo_wr					<= '0';	-- stop write
					sloe_drv						<= C_USB_SLOE_DISABLE_LEVEL;
					slwr_drv						<= C_USB_SLWR_PASSIVE;
					last_write 					<= '0';
					if(usb_rx_empty = '0')then
						sloe_drv					<= C_USB_SLOE_ENABLE_LEVEL;
						read_fsm_enable		<= '1';
						wr_fsm_state			<= STATE_READ_1;	-- V7
					elsif(tx_fifo_empty = '0'	and usb_tx_full = '0')then
						sloe_drv					<= C_USB_SLOE_DISABLE_LEVEL;
						tx_fifo_read_req	<= '1';
						read_fsm_enable		<= '0';
						wr_fsm_state			<= STATE_WR;
					end if;
					
				when STATE_WR =>
					sloe_drv						<= C_USB_SLOE_DISABLE_LEVEL;
					if(tx_fifo_empty = '1')then
						tx_fifo_read_req	<= '0';
						slwr_drv					<= C_USB_SLWR_PASSIVE;
						last_write 				<= '1';
						wr_fsm_state			<= STATE_WR_INIT;
					elsif(usb_tx_full = '1' or usb_rx_empty = '0')then
						tx_fifo_read_req	<= '0';
						slwr_drv					<= C_USB_SLWR_PASSIVE;
						wr_fsm_state			<= STATE_WR_REM;
					else
						tx_fifo_read_req	<= '1';
						slwr_drv					<= C_USB_SLWR_ACTIVE;
					end if;
				
				when STATE_WR_REM =>
					sloe_drv						<= C_USB_SLOE_DISABLE_LEVEL;
					slwr_drv						<= C_USB_SLWR_PASSIVE;
					if(usb_tx_full = '0')then
						wr_fsm_state			<= STATE_WR;
					end if;

				when STATE_READ_1 =>
					rx_fifo_wr		<= '0';	-- stop write
					wr_fsm_state					<= STATE_READ_2;
					
				when STATE_READ_2 =>
					rx_fifo_data	<= fd_i_reg;
					rx_fifo_wr		<= '1';	-- Write result
					if(usb_rx_empty = '0' -- We have something to read
						and rx_fifo_almostfull = '0'	-- and have room in FIFO
						)then	-- Go to next read cycle
						sloe_drv			<= C_USB_SLOE_ENABLE_LEVEL;	-- Drive OE
						wr_fsm_state					<= STATE_READ_1;
					else
						sloe_drv			<= C_USB_SLOE_DISABLE_LEVEL;	-- Disable OE
						wr_fsm_state					<= STATE_WR_INIT;
					end if;
					
				when others => null;
			end case;
		end if;
	end process;

process(USB_IFCLK)
begin
	if(USB_IFCLK = '1' and USB_IFCLK'event)then
		pktend_drv			<= last_write;
	end if;
end process;

fd_t_bit	<= '0' when (wr_fsm_state = STATE_WR) or (wr_fsm_state = STATE_WR_REM) else '1';

t_drv_gen: for j in 0 to 7 generate 
attribute iob of FDCE_inst 			: label is "true";
attribute box_type of FDCE_inst	: label is "black_box";
begin
	FDCE_inst : FDCE
	generic map (
		INIT 	=> '1'
	)
	port map (
		Q 		=> fd_t_drv(j),
		C 		=> USB_IFCLK,
		CE 		=> '1',
		CLR 	=> '0',
		D 		=> fd_t_bit
	);
end generate;

process(USB_IFCLK)
begin
	if(USB_IFCLK = '1' and USB_IFCLK'event)then
		if((wr_fsm_state = STATE_WR_INIT or wr_fsm_state = STATE_READ_2) and usb_rx_empty = '0' and rx_fifo_almostfull = '0')then
			slrd_drv			<= C_USB_SLRD_ACTIVE;	-- Start Read
		else
			slrd_drv			<= C_USB_SLRD_PASSIVE;
		end if;
	end if;
end process;
------------------------------------------
-- FIFOs
------------------------------------------
tx_fifo_reset_drv 	<= SYS_Rst or tx_fifo_rst;
rx_fifo_reset_drv 	<= SYS_Rst or rx_fifo_rst;
tx_fifo_reset 			<= tx_fifo_reset_drv;
rx_fifo_reset 			<= rx_fifo_reset_drv;
tx_addr_fifo_reset	<= tx_fifo_reset_drv;
fd_o_drv						<= tx_fifo_data;
tx_fifo_rd					<= '1' when (tx_fifo_empty = '0' and usb_tx_full = '0' and tx_fifo_read_req = '1') else '0';
tx_addr_fifo_rd			<= '1' when (tx_fifo_empty = '0' and usb_tx_full = '0' and tx_fifo_read_req = '1' and addr_fifo_rd_cnt = "00") else '0';
fifoaddr_drv		 		<= "11" when (read_fsm_enable = '1') else tx_addr_fifo_data when (C_USE_ADDR_FIFO=1) else REG_FIFOADR;
------------------------------------------
-- Address FIFO engine
------------------------------------------
process(tx_fifo_reset_drv, USB_IFCLK)
begin
	if(tx_fifo_reset_drv = '1')then
		addr_fifo_rd_cnt		<= (others => '0');
	elsif(USB_IFCLK = '1' and USB_IFCLK'event)then
		if(tx_fifo_empty = '0' and usb_tx_full = '0' and tx_fifo_read_req = '1')then
			addr_fifo_rd_cnt		<= addr_fifo_rd_cnt + 1;
		end if;
	end if;
end process;
------------------------------------------
-- INTERRUPT signals connection
------------------------------------------
Interrupt <= "0000" & rx_fifo_underflow & tx_fifo_overflow & rx_fifo_prog_full & tx_fifo_prog_empty;
------------------------------------------
-- FIFO threshold 
------------------------------------------
TX_FIFO_PROG_EMPTY_DETECT : process (SYS_Clk)
begin
	if (SYS_Clk'event and SYS_Clk	=	'1') then 
		if (tx_fifo_reset_drv = '1') then --reset
			tx_fifo_prog_empty <= '1';
		elsif (tx_fifo_count <= tx_fifo_threshold) then --under threshold
			tx_fifo_prog_empty <= '1';
		else
			tx_fifo_prog_empty <= '0';
		end	if;
	end	if;
end	process;

RX_FIFO_PROG_FULL_DETECT : process (SYS_Clk)
begin
	if (SYS_Clk'event and SYS_Clk	=	'1') then 
		if (tx_fifo_reset_drv = '1') then --reset
			rx_fifo_prog_full <= '0';
		elsif (rx_fifo_count >= rx_fifo_threshold) then --over threshold
			rx_fifo_prog_full <= '1';
		else
			rx_fifo_prog_full <= '0';
		end	if;
	end	if;
end	process;
------------------------------------------
-- Drive tx_fifo_rdy
------------------------------------------
tx_fifo_rdy <= '0' when ((tx_fifo_reset_drv = '1') or (tx_fifo_full = '1')) else TX_FIFO_RDY_reg;
------------------------------------------
end rtl;
