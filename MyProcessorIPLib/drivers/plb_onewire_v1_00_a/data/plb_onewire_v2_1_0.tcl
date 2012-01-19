##############################################################################
## Filename:          D:\Projekti\CAMOS\EDK\1st_system_v3/drivers/plb_singlewire_v2_00_a/data/plb_singlewire_v2_1_0.tcl
## Description:       Microprocess Driver Command (tcl)
## Date:              Wed Jun 30 17:34:33 2010 (by Create and Import Peripheral Wizard)
##############################################################################

#uses "xillib.tcl"

proc generate {drv_handle} {
  xdefine_include_file $drv_handle "xparameters.h" "plb_onewire" "NUM_INSTANCES" "DEVICE_ID" "C_BASEADDR" "C_HIGHADDR" 
}
