----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:15:10 02/12/2009 
-- Design Name: 
-- Module Name:    byte_swap - Behavioral 
-- Project Name: 
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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity byte_swap is
  generic (
    C_WIDTH  : integer := 32); --16, 32 or 64 bit bus
    Port ( input : in  STD_LOGIC_VECTOR (C_WIDTH-1 downto 0);
           output : out  STD_LOGIC_VECTOR (C_WIDTH-1 downto 0));
end byte_swap;

architecture Behavioral of byte_swap is

begin

HALF_WORD_SWAP:
	if (C_WIDTH = 16) generate
	 begin
	--byte swapping
	output(7 downto 0)   <= input(15 downto 8); --byte swapping
	output(15 downto 8)  <= input(7 downto 0); --byte swapping
 end generate;

LOWER32_WORD_SWAP:
	if (C_WIDTH > 16) generate
	 begin
	--byte swapping
	output(7 downto 0)   <= input(31 downto 24); --byte swapping
	output(15 downto 8)  <= input(23 downto 16); --byte swapping
	output(23 downto 16) <= input(15 downto 8); --byte swapping
	output(31 downto 24) <= input(7 downto 0); --byte swapping
 end generate;

UPPER32_WORD_SWAP:
	if (C_WIDTH = 64) generate
	 begin
		output(39 downto 32) <= input(63 downto 56); --byte swapping
		output(47 downto 40) <= input(55 downto 48); --byte swapping
		output(55 downto 48) <= input(47 downto 40); --byte swapping
		output(63 downto 56) <= input(39 downto 32); --byte swapping
	end generate;

end Behavioral;

