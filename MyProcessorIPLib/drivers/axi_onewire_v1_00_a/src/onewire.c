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

#if 0
int cam_eeprom_get_serial(void)
{
  unsigned char data[14];
  int try;
  /* try several times to read */
  for (try = 0; try < 5; try++) {
    LOG(MODULE, LOG_INFO, "Trying to read out serial number (%d)..", try+1);

    if (one_wire_reset()) {
      LOG(MODULE, LOG_ERROR, "one wire reset error");
      usleep(200000);
      continue;
    }

    one_wire_write(0xCC); /* op code for skip rom 0xcc, readrom 0x33 */

    /* read memory */
    one_wire_write(0xF0); /* command read mem */
    one_wire_write(0x00); /* address 0 */
    one_wire_write(0x00); /* address 1 */


    int i;
    for (i = 0; i < sizeof(data); i++) {
      data[i] = one_wire_read();
      printf("%02X ", data[i] & 0xFF);
    }
    printf("\n");

    /* check if we read out something sensible - these are constant bytes */
    if (memcmp(data, (unsigned char []){0x8d, 0x0a, 0x29, 0x11, 0x00, 0x00}, 6) != 0) {
      LOG(MODULE, LOG_ERROR, "Wrong EEPROM readout.");
      myusleep(500000);
      continue;
    }

    /* crc of 13 bytes (includes inverted crc16 code) must be 0xB001 */
    if (crc16(&data[1], 13) == 0xB001) {
      memcpy(cam.serial, &data[6], 3);
      LOG(MODULE, LOG_INFO, "Serial number from eeprom: %02X %02X %02X .",
          cam.serial[0], cam.serial[1], cam.serial[2]);
      return 1;
    } else {
      LOG(MODULE, LOG_ERROR, "EEPROM: inverted CRC16 not matching.");
      myusleep(500000);
    }
  }

  /* failed to obtain a serial number */
  cam.serial[0] = 0xAA;
  cam.serial[1] = 0xBB;
  cam.serial[2] = 0xCC;
  return 0;
}
#endif

