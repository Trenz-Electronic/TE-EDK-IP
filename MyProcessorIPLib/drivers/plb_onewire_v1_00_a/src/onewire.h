/*
 * singlewire.h
 *
 *  Created on: 11.2.2011
 *      Author: Ziga
 */

#ifndef SINGLEWIRE_H_
#define SINGLEWIRE_H_


unsigned char OneWireRead (unsigned int BaseAddrees);
void OneWireWrite (unsigned int BaseAddrees ,unsigned char data);
void OneWireReset (unsigned int BaseAddrees);
unsigned char crc8_calc(unsigned char *byt, unsigned int size );

#endif /* SINGLEWIRE_H_ */
