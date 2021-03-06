//////////////////////////////////////////////////////////////////////////////
// Filename:          E:\DOKTORAT\Projekti\HSS3\EDK\MyProcessorIPLib/drivers/xps_i2c_slave_v1_00_a/src/xps_i2c_slave.h
// Version:           1.00.a
// Description:       xps_i2c_slave Driver Header File
// Date:              Tue Apr 08 20:01:17 2008 (by Create and Import Peripheral Wizard)
//////////////////////////////////////////////////////////////////////////////

#ifndef XPS_I2C_SLAVE_H
#define XPS_I2C_SLAVE_H

/***************************** Include Files *******************************/

#include "xbasic_types.h"
#include "xstatus.h"
#include "xio.h"

/************************** Constant Definitions ***************************/

#define XPS_I2C_SLAVE_MB2FX2_REG0_OFFSET (0x00000000)
#define XPS_I2C_SLAVE_MB2FX2_REG1_OFFSET (0x00000004)
#define XPS_I2C_SLAVE_MB2FX2_REG2_OFFSET (0x00000008)
#define XPS_I2C_SLAVE_FX2MB_REG0_OFFSET  (0x0000000C)
#define XPS_I2C_SLAVE_FX2MB_REG1_OFFSET  (0x00000010)
#define XPS_I2C_SLAVE_FX2MB_REG2_OFFSET  (0x00000014)


/**
 * User Logic Slave Space Offsets
 * -- SLV_REG0 : user logic slave module register 0
 * -- SLV_REG1 : user logic slave module register 1
 * -- SLV_REG2 : user logic slave module register 2
 * -- SLV_REG3 : user logic slave module register 3
 * -- SLV_REG4 : user logic slave module register 4
 * -- SLV_REG5 : user logic slave module register 5
 */
#define XPS_I2C_SLAVE_USER_SLV_SPACE_OFFSET (0x00000000)
#define XPS_I2C_SLAVE_SLV_REG0_OFFSET (XPS_I2C_SLAVE_USER_SLV_SPACE_OFFSET + 0x00000000)
#define XPS_I2C_SLAVE_SLV_REG1_OFFSET (XPS_I2C_SLAVE_USER_SLV_SPACE_OFFSET + 0x00000004)
#define XPS_I2C_SLAVE_SLV_REG2_OFFSET (XPS_I2C_SLAVE_USER_SLV_SPACE_OFFSET + 0x00000008)
#define XPS_I2C_SLAVE_SLV_REG3_OFFSET (XPS_I2C_SLAVE_USER_SLV_SPACE_OFFSET + 0x0000000C)
#define XPS_I2C_SLAVE_SLV_REG4_OFFSET (XPS_I2C_SLAVE_USER_SLV_SPACE_OFFSET + 0x00000010)
#define XPS_I2C_SLAVE_SLV_REG5_OFFSET (XPS_I2C_SLAVE_USER_SLV_SPACE_OFFSET + 0x00000014)

/**
 * Software Reset Space Register Offsets
 * -- RST : software reset register
 */
#define XPS_I2C_SLAVE_SOFT_RST_SPACE_OFFSET (0x00000100)
#define XPS_I2C_SLAVE_RST_REG_OFFSET (XPS_I2C_SLAVE_SOFT_RST_SPACE_OFFSET + 0x00000000)

/**
 * Software Reset Masks
 * -- SOFT_RESET : software reset
 */
#define SOFT_RESET (0x0000000A)

/**************************** Type Definitions *****************************/


/***************** Macros (Inline Functions) Definitions *******************/

/**
 *
 * Write a value to a XPS_I2C_SLAVE register. A 32 bit write is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is written.
 *
 * @param   BaseAddress is the base address of the XPS_I2C_SLAVE device.
 * @param   RegOffset is the register offset from the base to write to.
 * @param   Data is the data written to the register.
 *
 * @return  None.
 *
 * @note
 * C-style signature:
 * 	void XPS_I2C_SLAVE_mWriteReg(Xuint32 BaseAddress, unsigned RegOffset, Xuint32 Data)
 *
 */
#define XPS_I2C_SLAVE_mWriteReg(BaseAddress, RegOffset, Data) \
 	XIo_Out32((BaseAddress) + (RegOffset), (Xuint32)(Data))

/**
 *
 * Read a value from a XPS_I2C_SLAVE register. A 32 bit read is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is read from the register. The most significant data
 * will be read as 0.
 *
 * @param   BaseAddress is the base address of the XPS_I2C_SLAVE device.
 * @param   RegOffset is the register offset from the base to write to.
 *
 * @return  Data is the data from the register.
 *
 * @note
 * C-style signature:
 * 	Xuint32 XPS_I2C_SLAVE_mReadReg(Xuint32 BaseAddress, unsigned RegOffset)
 *
 */
#define XPS_I2C_SLAVE_mReadReg(BaseAddress, RegOffset) \
 	XIo_In32((BaseAddress) + (RegOffset))


/**
 *
 * Write/Read 32 bit value to/from XPS_I2C_SLAVE user logic slave registers.
 *
 * @param   BaseAddress is the base address of the XPS_I2C_SLAVE device.
 * @param   RegOffset is the offset from the slave register to write to or read from.
 * @param   Value is the data written to the register.
 *
 * @return  Data is the data from the user logic slave register.
 *
 * @note
 * C-style signature:
 * 	void XPS_I2C_SLAVE_mWriteSlaveRegn(Xuint32 BaseAddress, unsigned RegOffset, Xuint32 Value)
 * 	Xuint32 XPS_I2C_SLAVE_mReadSlaveRegn(Xuint32 BaseAddress, unsigned RegOffset)
 *
 */
#define XPS_I2C_SLAVE_mWriteSlaveReg0(BaseAddress, RegOffset, Value) \
 	XIo_Out32((BaseAddress) + (XPS_I2C_SLAVE_SLV_REG0_OFFSET) + (RegOffset), (Xuint32)(Value))
#define XPS_I2C_SLAVE_mWriteSlaveReg1(BaseAddress, RegOffset, Value) \
 	XIo_Out32((BaseAddress) + (XPS_I2C_SLAVE_SLV_REG1_OFFSET) + (RegOffset), (Xuint32)(Value))
#define XPS_I2C_SLAVE_mWriteSlaveReg2(BaseAddress, RegOffset, Value) \
 	XIo_Out32((BaseAddress) + (XPS_I2C_SLAVE_SLV_REG2_OFFSET) + (RegOffset), (Xuint32)(Value))
#define XPS_I2C_SLAVE_mWriteSlaveReg3(BaseAddress, RegOffset, Value) \
 	XIo_Out32((BaseAddress) + (XPS_I2C_SLAVE_SLV_REG3_OFFSET) + (RegOffset), (Xuint32)(Value))
#define XPS_I2C_SLAVE_mWriteSlaveReg4(BaseAddress, RegOffset, Value) \
 	XIo_Out32((BaseAddress) + (XPS_I2C_SLAVE_SLV_REG4_OFFSET) + (RegOffset), (Xuint32)(Value))
#define XPS_I2C_SLAVE_mWriteSlaveReg5(BaseAddress, RegOffset, Value) \
 	XIo_Out32((BaseAddress) + (XPS_I2C_SLAVE_SLV_REG5_OFFSET) + (RegOffset), (Xuint32)(Value))

#define XPS_I2C_SLAVE_mReadSlaveReg0(BaseAddress, RegOffset) \
 	XIo_In32((BaseAddress) + (XPS_I2C_SLAVE_SLV_REG0_OFFSET) + (RegOffset))
#define XPS_I2C_SLAVE_mReadSlaveReg1(BaseAddress, RegOffset) \
 	XIo_In32((BaseAddress) + (XPS_I2C_SLAVE_SLV_REG1_OFFSET) + (RegOffset))
#define XPS_I2C_SLAVE_mReadSlaveReg2(BaseAddress, RegOffset) \
 	XIo_In32((BaseAddress) + (XPS_I2C_SLAVE_SLV_REG2_OFFSET) + (RegOffset))
#define XPS_I2C_SLAVE_mReadSlaveReg3(BaseAddress, RegOffset) \
 	XIo_In32((BaseAddress) + (XPS_I2C_SLAVE_SLV_REG3_OFFSET) + (RegOffset))
#define XPS_I2C_SLAVE_mReadSlaveReg4(BaseAddress, RegOffset) \
 	XIo_In32((BaseAddress) + (XPS_I2C_SLAVE_SLV_REG4_OFFSET) + (RegOffset))
#define XPS_I2C_SLAVE_mReadSlaveReg5(BaseAddress, RegOffset) \
 	XIo_In32((BaseAddress) + (XPS_I2C_SLAVE_SLV_REG5_OFFSET) + (RegOffset))

/**
 *
 * Reset XPS_I2C_SLAVE via software.
 *
 * @param   BaseAddress is the base address of the XPS_I2C_SLAVE device.
 *
 * @return  None.
 *
 * @note
 * C-style signature:
 * 	void XPS_I2C_SLAVE_mReset(Xuint32 BaseAddress)
 *
 */
#define XPS_I2C_SLAVE_mReset(BaseAddress) \
 	XIo_Out32((BaseAddress)+(XPS_I2C_SLAVE_RST_REG_OFFSET), SOFT_RESET)

/************************** Function Prototypes ****************************/


/**
 *
 * Run a self-test on the driver/device. Note this may be a destructive test if
 * resets of the device are performed.
 *
 * If the hardware system is not built correctly, this function may never
 * return to the caller.
 *
 * @param   baseaddr_p is the base address of the XPS_I2C_SLAVE instance to be worked on.
 *
 * @return
 *
 *    - XST_SUCCESS   if all self-test code passed
 *    - XST_FAILURE   if any self-test code failed
 *
 * @note    Caching must be turned off for this function to work.
 * @note    Self test may fail if data memory and device are not on the same bus.
 *
 */
XStatus XPS_I2C_SLAVE_SelfTest(void * baseaddr_p);

#endif // XPS_I2C_SLAVE_H
