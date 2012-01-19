#include "xio.h"
#include "onewire.h"


 void OneWireReset (unsigned int BaseAddrees) {
	volatile int x;
	
	// Reset the 1-wire bus
	XIo_Out32 (BaseAddrees + 0x8,0x3);		// Send the opcode for a bus reset
	XIo_Out32 (BaseAddrees + 0xC,0x1);		// Execute!
	
	// Wait a little while...
	x=0;
	while (x < 25000) {
		x++;
	}
 }
 
 void OneWireWrite (unsigned int BaseAddrees ,unsigned char data) {
	volatile int x;
	volatile unsigned char ReadBUF;
	
	// Send skip ROM command
	XIo_Out32 (BaseAddrees + 0x8,0x1);		// Send the opcode for a write
	XIo_Out32 (BaseAddrees + 0x4,data);		// Send the data for a write
	XIo_Out32 (BaseAddrees + 0xC,0x1);		// Execute!

	// Wait a little while...
	x=0;
	while (x < 5000) {
		x++;
	}
 }
 
 unsigned char OneWireRead (unsigned int BaseAddrees) {
	volatile int x;
	volatile unsigned char ReadBUF;
 
	// Read a byte
	XIo_Out32 (BaseAddrees + 0x8,0x2);		// Send the opcode for a read
	XIo_Out32 (BaseAddrees + 0xC,0x1);		// Execute!
	
	// Wait a little while...
	x=0;
	while (x < 5000) {
		x++;
	}
	
	ReadBUF = XIo_In32(BaseAddrees + 0x0);	// Read the data
	return ReadBUF;
 }
 
 unsigned char crc8_calc(unsigned char *byt, unsigned int size )
 {
	 /* Calculate CRC-8 value; uses The CCITT-8 polynomial,
	 expressed as X^8 + X^5 + X^4 + 1 */

	 unsigned char crc = (unsigned char) 0xff;
	 unsigned int index;
	 unsigned char b;

	 for( index=0; index<size; index++)
	{
		 crc ^= byt[index];
		 for( b=0; b<8; ++b )
		{
			 if( crc & 0x80 )
			 crc = (crc << 1) ^ 0x31;
			 else
			 crc = (crc << 1);
		 }
	 }
	 return crc;
 }


