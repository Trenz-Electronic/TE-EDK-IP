##############################################################################
## Filename:          E:\DOKTORAT\Projekti\HSS3\EDK\MyProcessorIPLib/drivers/xps_i2c_slave_v1_00_a/data/xps_i2c_slave_v2_1_0.tcl
## Description:       Microprocess Driver Command (tcl)
## Date:              Tue Apr 08 20:01:17 2008 (by Create and Import Peripheral Wizard)
##############################################################################

#uses "xillib.tcl"

proc generate {drv_handle} {
  xdefine_include_file $drv_handle "xparameters.h" "xps_i2c_slave" "NUM_INSTANCES" "DEVICE_ID" "C_BASEADDR" "C_HIGHADDR" 
}
