/*
 * onewire.h
 *
 *  Created on: 11.2.2011
 *      Author: Ziga
 */

#ifndef ONEWIRE_H_
#define ONEWIRE_H_

/**
 * Software Reset Masks
 * -- SOFT_RESET : software reset
 */
#define SOFT_RESET (0x0000000A)

/**
 *
 * Reset AXI_ONEWIRE via software.
 *
 * @param   BaseAddress is the base address of the AXI_ONEWIRE device.
 *
 * @return  None.
 *
 * @note
 * C-style signature:
 * 	void AXI_ONEWIRE_mReset(Xuint32 BaseAddress)
 *
 */
#define AXI_ONEWIRE_SOFT_RST_SPACE_OFFSET (0x00000100)
#define AXI_ONEWIRE_RST_REG_OFFSET (AXI_ONEWIRE_SOFT_RST_SPACE_OFFSET + 0x00000000)

#define AXI_ONEWIRE_mReset(BaseAddress) \
 	Xil_Out32((BaseAddress)+(AXI_ONEWIRE_RST_REG_OFFSET), SOFT_RESET)

unsigned char OneWireRead (unsigned int BaseAddress);
void OneWireWrite (unsigned int BaseAddress, unsigned char data);
void OneWireReset (unsigned int BaseAddress);
unsigned char crc8_calc(unsigned char *byt, unsigned int size );

#endif /* ONEWIRE_H_ */
