##############################################################################
## Filename:          C:\XilinxWorkspace\GigaBee_XC6LX-Axi_original\repo\MyProcessorIPLib/drivers/axi_onewire_v1_00_a/data/axi_onewire_v2_1_0.tcl
## Description:       Microprocess Driver Command (tcl)
## Date:              Tue Dec 27 12:57:06 2011 (by Create and Import Peripheral Wizard)
##############################################################################

#uses "xillib.tcl"

proc generate {drv_handle} {
  xdefine_include_file $drv_handle "xparameters.h" "axi_onewire" "NUM_INSTANCES" "DEVICE_ID" "C_BASEADDR" "C_HIGHADDR" 
}
