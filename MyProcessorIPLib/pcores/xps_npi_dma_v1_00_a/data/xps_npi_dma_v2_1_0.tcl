##############################################################################
## Filename:          E:\DOKTORAT\Projekti\HSS4\EDK\HSS4_v0.1.0.0/drivers/xps_npi_dma_v1_00_a/data/xps_npi_dma_v2_1_0.tcl
## Description:       Microprocess Driver Command (tcl)
## Date:              Thu Sep 11 16:59:40 2008 (by Create and Import Peripheral Wizard)
##############################################################################

#uses "xillib.tcl"

proc generate {drv_handle} {
  xdefine_include_file $drv_handle "xparameters.h" "xps_npi_dma" "NUM_INSTANCES" "DEVICE_ID" "C_BASEADDR" "C_HIGHADDR" 
}
