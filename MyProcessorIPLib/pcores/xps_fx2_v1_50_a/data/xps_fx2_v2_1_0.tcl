##----------------------------------------------------------------------------
## $Revision: 1.5 $
## $Date: 2005/09/15 01:44:39 $
##----------------------------------------------------------------------------
## xps_fx2
##----------------------------------------------------------------------------
##
##  ***************************************************************************
##  **  Copyright(C) 2005 by Xilinx, Inc. All rights reserved.               **
##  **                                                                       **
##  **  This text contains proprietary, confidential                         **
##  **  information of Xilinx, Inc. , is distributed by                      **
##  **  under license from Xilinx, Inc., and may be used,                    **
##  **  copied and/or disclosed only pursuant to the terms                   **
##  **  of a valid license agreement with Xilinx, Inc.                       **
##  **                                                                       **
##  **  Unmodified source code is guaranteed to place and route,             **
##  **  function and run at speed according to the datasheet                 **
##  **  specification. Source code is provided "as-is", with no              **
##  **  obligation on the part of Xilinx to provide support.                 **
##  **                                                                       **
##  **  Xilinx Hotline support of source code IP shall only include          **
##  **  standard level Xilinx Hotline support, and will only address         **
##  **  issues and questions related to the standard released Netlist        **
##  **  version of the core (and thus indirectly, the original core source). **
##  **                                                                       **
##  **  The Xilinx Support Hotline does not have access to source            **
##  **  code and therefore cannot answer specific questions related          **
##  **  to source HDL. The Xilinx Support Hotline will only be able          **
##  **  to confirm the problem in the Netlist version of the core.           **
##  **                                                                       **
##  **  This copyright and support notice must be retained as part           **
##  **  of this text at all times.                                           **
##  ***************************************************************************
##
##----------------------------------------------------------------------------
## Filename:          xps_fx2_v2_1_0.tcl
##
##----------------------------------------------------------------------------
## Author:    AG
## History:
##  AG        03.08.2009      - Updated to support S3A DSP and generation of all fifos
##  ole2      10.02.2011      - Fixed for CoreGen 7.2 and Xilinx 12.4 environment
##
##----------------------------------------------------------------------------

proc xps_fx2_generate { handle } {

##------COPY OTHER NETLIST FILE
	#file copy -force [pwd]/pcores/xps_fx2_v1_00_a/netlist/rx_fifo.ngc [pwd]/implementation/
	#file copy -force [pwd]/pcores/xps_fx2_v1_00_a/netlist/tx_addr_fifo.ngc [pwd]/implementation/

  set param_names {
        "INSTANCE"
        "HW_VER"
        "C_FAMILY"
        "C_TX_FIFO_KBYTE"
        "C_RX_FIFO_KBYTE"
        "C_USE_ADDR_FIFO"
      }

  set param_table {}

  foreach name $param_names {
    lappend param_table $name
    lappend param_table [xget_value $handle "PARAMETER" $name]
  }

  # put the PARAMETER name value pairs into an associative array
  # for easy access Ex: set instance_name $params(INSTANCE)
  array set params $param_table
  set cg_projdir [pwd]/implementation/$params(INSTANCE)_wrapper
  set logfilename "$cg_projdir/$params(INSTANCE)_fifo.log"
  set logfile [open $logfilename "w"]

##------GENERATE tx_fifo
  set tx_fifo_detect 0

  if { [file exists $cg_projdir/tx_fifo.ngc] } {
    puts "Detected tx_fifo.ngc"
    puts $logfile "Detected tx_fifo.ngc"
    if { [file exists $cg_projdir/$params(INSTANCE)_tx_fifo$params(C_TX_FIFO_KBYTE)k.arg] } {
      puts "Detected tx_fifo is of a right size"
    	puts $logfile "Detected tx_fifo is of a right size"
    	set tx_fifo_detect 1
    }
  }


  if { $tx_fifo_detect == 1 } {
		file copy -force $cg_projdir/tx_fifo.ngc [pwd]/implementation/
  }

	if { $tx_fifo_detect == 0 } {
	
  puts ""
  puts "*******************************************************************"
  puts "* $params(INSTANCE) : Generating TX FIFO LogiCORE"
  puts "*******************************************************************"
  puts ""
  puts "  Param values are : $param_table"
  puts ""
  puts $logfile "**********************************************************"
  puts $logfile "* $params(INSTANCE)"
  puts $logfile "**********************************************************"

  ############################################################################
  # Write out a Core Generator arg file that matches
  # the parameters set by the user.
  ############################################################################

  set projectfilename "$cg_projdir/coregen.cgp"
  set argfile [open $projectfilename "w"]

  #must be for any fifo
  puts $argfile "NEWPROJECT $cg_projdir"
  puts $argfile "SETPROJECT $cg_projdir"
	puts $argfile "# BEGIN Project Options"
	puts $argfile "SET addpads = False"
	puts $argfile "SET asysymbol = True"
	puts $argfile "SET busformat = BusFormatAngleBracketNotRipped"
	puts $argfile "SET createndf = False"
	puts $argfile "SET designentry = VHDL"

  switch $params(C_FAMILY) {
    "spartan3e" {
      puts $argfile "SET device = xc3s500e"
			puts $argfile "SET devicefamily = spartan3e"
    }
    "spartan3" {
      puts $argfile "SET device = xc3s400"
			puts $argfile "SET devicefamily = spartan3"
    }
    "spartan3adsp" {
      puts $argfile "SET device = xc3sd1800a"
			puts $argfile "SET devicefamily = spartan3adsp"
    } 
    "spartan6" {
      puts $argfile "SET device = xc6slx25"
			puts $argfile "SET devicefamily = spartan6"
    } 
    default {
      puts "ERROR:invalid family $params(C_FAMILY)!!"
    } 
  }
	puts $argfile "SET flowvendor = Foundation_iSE"
	puts $argfile "SET formalverification = False"
	puts $argfile "SET foundationsym = False"
	puts $argfile "SET implementationfiletype = Ngc"
	 
	switch $params(C_FAMILY) {
    "spartan6" {
      puts $argfile "SET package = ftg256"
      puts $argfile "SET speedgrade = -3"
    } 
    "spartan3adsp" {
      puts $argfile "SET package = fg676"
      puts $argfile "SET speedgrade = -4"
    } 
    default {
      puts $argfile "SET package = pq208"
      puts $argfile "SET speedgrade = -4"
    } 
  }
  
	      
	puts $argfile "SET removerpms = False"
	puts $argfile "SET simulationfiles = Behavioral"
	puts $argfile "SET verilogsim = True"

	puts $argfile "SET vhdlsim = False"
	puts $argfile "# END Project Options"
  close $argfile
	
  set filename "$cg_projdir/$params(INSTANCE)_tx_fifo$params(C_TX_FIFO_KBYTE)k.arg"
  set argfile [open $filename "w"]
	puts $argfile "SELECT Fifo_Generator family Xilinx,_Inc. 7.2"
	
  # FOR tx_fifo
  
    set tx_fifo_size $params(C_TX_FIFO_KBYTE)
    
    puts $argfile "# BEGIN Parameters"                                   
    puts $argfile "CSET almost_empty_flag=false"                         
    puts $argfile "CSET almost_full_flag=true"                          
    puts $argfile "CSET component_name=tx_fifo"                          
    puts $argfile "CSET data_count=false"
    switch $tx_fifo_size {
      "2" {
 				puts $argfile "CSET data_count_width=9"
      }
      "4" {
				puts $argfile "CSET data_count_width=10"
      }
      "8" {
				puts $argfile "CSET data_count_width=11"
      }
	  "16" {
				puts $argfile "CSET data_count_width=12"
      }
	  "32" {
				puts $argfile "CSET data_count_width=13"
      }
      default {
				puts $argfile "CSET data_count_width=9"
      }
    }                                                              
    puts $argfile "CSET dout_reset_value=0"                              
    puts $argfile "CSET empty_threshold_assert_value=2"                  
    puts $argfile "CSET empty_threshold_negate_value=3"                  
    puts $argfile "CSET enable_ecc=false"                                
#    puts $argfile "CSET enable_int_clk=false"                            
    puts $argfile "CSET fifo_implementation=Independent_Clocks_Block_RAM"
    puts $argfile "CSET full_flags_reset_value=0"                        
    switch $tx_fifo_size {
      "2" {
       puts $argfile "CSET full_threshold_assert_value=509"
       puts $argfile "CSET full_threshold_negate_value=508"
       puts $argfile "CSET input_data_width=32"
       puts $argfile "CSET input_depth=512"
       puts $argfile "CSET output_data_width=8"
			 puts $argfile "CSET output_depth=2048"
      }

      "4" {
       puts $argfile "CSET full_threshold_assert_value=1018"
       puts $argfile "CSET full_threshold_negate_value=1016"
       puts $argfile "CSET input_data_width=32"
       puts $argfile "CSET input_depth=1024"
       puts $argfile "CSET output_data_width=8"
			 puts $argfile "CSET output_depth=4096"
      }

      "8" {
       puts $argfile "CSET full_threshold_assert_value=2036"
       puts $argfile "CSET full_threshold_negate_value=2032"
       puts $argfile "CSET input_data_width=32"
       puts $argfile "CSET input_depth=2048"
       puts $argfile "CSET output_data_width=8"
			 puts $argfile "CSET output_depth=8192"
      }
	  "16" {
       puts $argfile "CSET full_threshold_assert_value=4072"
       puts $argfile "CSET full_threshold_negate_value=4064"
       puts $argfile "CSET input_data_width=32"
       puts $argfile "CSET input_depth=4096"
       puts $argfile "CSET output_data_width=8"
			 puts $argfile "CSET output_depth=16384"
      }
	  "32" {
       puts $argfile "CSET full_threshold_assert_value=8114"
       puts $argfile "CSET full_threshold_negate_value=8128"
       puts $argfile "CSET input_data_width=32"
       puts $argfile "CSET input_depth=8192"
       puts $argfile "CSET output_data_width=8"
			 puts $argfile "CSET output_depth=32768"
      }

      default {
       puts $argfile "CSET full_threshold_assert_value=509"
       puts $argfile "CSET full_threshold_negate_value=508"
       puts $argfile "CSET input_data_width=32"
       puts $argfile "CSET input_depth=512"
       puts $argfile "CSET output_data_width=8"
			 puts $argfile "CSET output_depth=2048"
      }
    }

    puts $argfile "CSET overflow_flag=true"
    puts $argfile "CSET overflow_sense=Active_High"
    puts $argfile "CSET performance_options=Standard_FIFO"
    puts $argfile "CSET programmable_empty_type=No_Programmable_Empty_Threshold"
    puts $argfile "CSET programmable_full_type=No_Programmable_Full_Threshold"
    puts $argfile "CSET read_clock_frequency=1"
    puts $argfile "CSET read_data_count=false"
    puts $argfile "CSET read_data_count_width=11"
    puts $argfile "CSET reset_pin=true"
    puts $argfile "CSET reset_type=Asynchronous_Reset"
    puts $argfile "CSET underflow_flag=true"
    puts $argfile "CSET underflow_sense=Active_High"
    puts $argfile "CSET use_dout_reset=true"
    puts $argfile "CSET use_embedded_registers=false"
    puts $argfile "CSET use_extra_logic=false"
    puts $argfile "CSET valid_flag=true"
    puts $argfile "CSET valid_sense=Active_High"
    puts $argfile "CSET write_acknowledge_flag=false"
    puts $argfile "CSET write_acknowledge_sense=Active_High"
    puts $argfile "CSET write_clock_frequency=1"
    puts $argfile "CSET write_data_count=true"
    switch $tx_fifo_size {
      "2" {
 				puts $argfile "CSET write_data_count_width=9"
      }
      "4" {
				puts $argfile "CSET write_data_count_width=10"
      }
      "8" {
				puts $argfile "CSET write_data_count_width=11"
      }
	  "16" {
				puts $argfile "CSET write_data_count_width=12"
      }
	  "32" {
				puts $argfile "CSET write_data_count_width=13"
      }
      default {
				puts $argfile "CSET write_data_count_width=9"
      }
    }
    puts $argfile "# END Parameters"
    puts $argfile "GENERATE"

  

  close $argfile

  ############################################################################
  # Call Core Generator with the arg file to create
  # the core netlist in <proj>/implementation/CORE_INSTANCENAME/.
  # Platgen will run ngcbuild from this location to merge the netlists
  # into a single NGC file. This helps in case of multiple instantiations
  # of the same core.
  ############################################################################

  puts "  $params(INSTANCE) : Running Core Generator to generate TX FIFO."
  puts "    * This will take several minutes. . ."
  puts ""
  puts $logfile "$params(INSTANCE) : Running Core Generator to generate TX FIFO. . ."
  file mkdir $cg_projdir
  catch { exec coregen -p $projectfilename -b $filename } msg

    if { [file exists $cg_projdir/tx_fifo.ngc] } {
			file copy -force $cg_projdir/tx_fifo.ngc [pwd]/implementation/
      puts ""
      puts "*******************************************************************"
      puts "* Successfully generated the TX FIFO LogiCORE: $params(INSTANCE)"
      puts "*  - copied to ./implementation/$params(INSTANCE)_wrapper/"
      puts "*******************************************************************"
      puts ""
	  file del $cg_projdir/coregen.cgc
    } else {
      puts "$params(INSTANCE): ERROR - TX FIFO Core Generation Failed"
      puts ""
      puts $logfile "$params(INSTANCE): ERROR TX FIFO Core Generation Failed"
      puts ""
      puts $logfile ""
      close $logfile
  		return
    }

  puts ""
  
  }


    ##------GENERATE tx_addr_fifo
	  set tx_addr_fifo_detect 0
	
	  if { [file exists $cg_projdir/tx_addr_fifo.ngc] } {
	    puts "Detected tx_addr_fifo.ngc"
	    puts $logfile "Detected tx_addr_fifo.ngc"
	    if { [file exists $cg_projdir/$params(INSTANCE)_tx_addr_fifo$params(C_TX_FIFO_KBYTE)k.arg] } {
	    	set tx_addr_fifo_detect 1
	    }
	  }
	
	  if { $tx_addr_fifo_detect == 1 } {
			file copy -force $cg_projdir/tx_addr_fifo.ngc [pwd]/implementation/
	  }
	  if {$params(C_USE_ADDR_FIFO) == 0} {
      set tx_addr_fifo_detect 1
 	  }
	  if { $tx_addr_fifo_detect == 0 } {
		  puts ""
		  puts "*******************************************************************"
		  puts "* $params(INSTANCE) : Generating TX ADDR FIFO LogiCORE"
		  puts "*******************************************************************"
		  puts ""
		  puts "  Param values are : $param_table"
		  puts ""
		  puts $logfile "**********************************************************"
		  puts $logfile "* $params(INSTANCE)"
		  puts $logfile "**********************************************************"
		
		  ############################################################################
		  # Write out a Core Generator arg file that matches
		  # the parameters set by the user.
		  ############################################################################
		
		  set filename "$cg_projdir/$params(INSTANCE)_tx_addr_fifo$params(C_RX_FIFO_KBYTE)k.arg"
		  set argfile [open $filename "w"]
		
		  #must be for any fifo
#		  puts $argfile "NEWPROJECT $cg_projdir"
#		  puts $argfile "SETPROJECT $cg_projdir"
#			puts $argfile "# BEGIN Project Options"
#			puts $argfile "SET addpads = False"
#			puts $argfile "SET asysymbol = True"
#			puts $argfile "SET busformat = BusFormatAngleBracketNotRipped"
#			puts $argfile "SET createndf = False"
#			puts $argfile "SET designentry = VHDL"
#		  switch $params(C_FAMILY) {
#		    "spartan3e" {
#		      puts $argfile "SET device = xc3s500e"
#					puts $argfile "SET devicefamily = spartan3e"
#		    }
#		    "spartan3" {
#		      puts $argfile "SET device = xc3s400"
#					puts $argfile "SET devicefamily = spartan3"
#		    }
#		    "spartan3adsp" {
#		      puts $argfile "SET device = xc3sd1800a"
#					puts $argfile "SET devicefamily = spartan3adsp"
#		    } 
#                    "spartan6" {
#                      puts $argfile "SET device = xc6slx25"
#			                puts $argfile "SET devicefamily = spartan6"
#                    } 
#		    default {
#		      puts "ERROR:invalid family $params(C_FAMILY)!!"
#		    } 
#		  }
#			puts $argfile "SET flowvendor = Foundation_iSE"
#			puts $argfile "SET formalverification = False"
#			puts $argfile "SET foundationsym = False"
#			puts $argfile "SET implementationfiletype = Ngc"
#			switch $params(C_FAMILY) {
#                    "spartan6" {
#                      puts $argfile "SET package = ftg256"
#                      puts $argfile "SET speedgrade = -3"
#                    } 
#		    "spartan3adsp" {
#		      puts $argfile "SET package = fg676"
#		      puts $argfile "SET speedgrade = -4"
#		    } 
#		    default {
#		      puts $argfile "SET package = pq208"
#		      puts $argfile "SET speedgrade = -4"
#		    } 
#		  }
#			puts $argfile "SET removerpms = False"
#			puts $argfile "SET simulationfiles = Behavioral"
#			puts $argfile "SET verilogsim = True"
#			puts $argfile "SET vhdlsim = True"
#			puts $argfile "# END Project Options"
		
			puts $argfile "# BEGIN Select"
			puts $argfile "SELECT Fifo_Generator family Xilinx,_Inc. 7.2"
			puts $argfile "# END Select"
			puts $argfile "# BEGIN Parameters"
			puts $argfile "CSET almost_empty_flag=false"
			puts $argfile "CSET almost_full_flag=false"
			puts $argfile "CSET component_name=tx_addr_fifo"
			puts $argfile "CSET data_count=false"
			puts $argfile "CSET data_count_width=9"
			puts $argfile "CSET dout_reset_value=0"
			puts $argfile "CSET empty_threshold_assert_value=4"
			puts $argfile "CSET empty_threshold_negate_value=5"
			puts $argfile "CSET enable_ecc=false"
#			puts $argfile "CSET enable_int_clk=false"
			puts $argfile "CSET fifo_implementation=Independent_Clocks_Distributed_RAM"
			puts $argfile "CSET full_flags_reset_value=0"
			
			switch $tx_fifo_size {
	      "2" {
	       puts $argfile "CSET full_threshold_assert_value=509"
	       puts $argfile "CSET full_threshold_negate_value=508"
	       puts $argfile "CSET input_data_width=2"
	       puts $argfile "CSET input_depth=512"
	       puts $argfile "CSET output_data_width=2"
				 puts $argfile "CSET output_depth=512"
	      }
	
	      "4" {
	       puts $argfile "CSET full_threshold_assert_value=1018"
	       puts $argfile "CSET full_threshold_negate_value=1016"
	       puts $argfile "CSET input_data_width=2"
	       puts $argfile "CSET input_depth=1024"
	       puts $argfile "CSET output_data_width=2"
				 puts $argfile "CSET output_depth=1024"
	      }
	
	      "8" {
	       puts $argfile "CSET full_threshold_assert_value=2036"
	       puts $argfile "CSET full_threshold_negate_value=2032"
	       puts $argfile "CSET input_data_width=2"
	       puts $argfile "CSET input_depth=2048"
	       puts $argfile "CSET output_data_width=2"
				 puts $argfile "CSET output_depth=2048"
	      }
		  "16" {
	       puts $argfile "CSET full_threshold_assert_value=2036"
	       puts $argfile "CSET full_threshold_negate_value=2032"
	       puts $argfile "CSET input_data_width=2"
	       puts $argfile "CSET input_depth=4096"
	       puts $argfile "CSET output_data_width=2"
				 puts $argfile "CSET output_depth=4096"
	      }
		  "32" {
	       puts $argfile "CSET full_threshold_assert_value=2036"
	       puts $argfile "CSET full_threshold_negate_value=2032"
	       puts $argfile "CSET input_data_width=2"
	       puts $argfile "CSET input_depth=8192"
	       puts $argfile "CSET output_data_width=2"
				 puts $argfile "CSET output_depth=8192"
	      }
	      default {
	       puts $argfile "CSET full_threshold_assert_value=509"
	       puts $argfile "CSET full_threshold_negate_value=508"
	       puts $argfile "CSET input_data_width=2"
	       puts $argfile "CSET input_depth=512"
	       puts $argfile "CSET output_data_width=2"
				 puts $argfile "CSET output_depth=512"
	      }
	    }
			
			puts $argfile "CSET overflow_flag=false"
			puts $argfile "CSET overflow_sense=Active_High"
			puts $argfile "CSET performance_options=First_Word_Fall_Through"
			puts $argfile "CSET programmable_empty_type=No_Programmable_Empty_Threshold"
			puts $argfile "CSET programmable_full_type=No_Programmable_Full_Threshold"
			puts $argfile "CSET read_clock_frequency=1"
			puts $argfile "CSET read_data_count=false"
			puts $argfile "CSET read_data_count_width=9"
			puts $argfile "CSET reset_pin=true"
			puts $argfile "CSET reset_type=Asynchronous_Reset"
			puts $argfile "CSET underflow_flag=false"
			puts $argfile "CSET underflow_sense=Active_High"
			puts $argfile "CSET use_dout_reset=true"
			puts $argfile "CSET use_embedded_registers=false"
			puts $argfile "CSET use_extra_logic=false"
			puts $argfile "CSET valid_flag=false"
			puts $argfile "CSET valid_sense=Active_High"
			puts $argfile "CSET write_acknowledge_flag=false"
			puts $argfile "CSET write_acknowledge_sense=Active_High"
			puts $argfile "CSET write_clock_frequency=1"
			puts $argfile "CSET write_data_count=false"
			puts $argfile "CSET write_data_count_width=9"
			puts $argfile "# END Parameters"
			puts $argfile "GENERATE"
    	puts $argfile "GENERATE"

  		close $argfile

	  ############################################################################
	  # Call Core Generator with the arg file to create
	  # the core netlist in <proj>/implementation/CORE_INSTANCENAME/.
	  # Platgen will run ngcbuild from this location to merge the netlists
	  # into a single NGC file. This helps in case of multiple instantiations
	  # of the same core.
	  ############################################################################
	
	  puts "  $params(INSTANCE) : Running Core Generator to generate TX ADDR FIFO."
	  puts "    * This will take several minutes. . ."
	  puts ""
	  puts $logfile "$params(INSTANCE) : Running Core Generator to generate TX ADDR FIFO. . ."
	  catch { exec coregen -p $projectfilename -b $filename } msg

    if { [file exists $cg_projdir/tx_addr_fifo.ngc] } {
			file copy -force $cg_projdir/tx_addr_fifo.ngc [pwd]/implementation/
      puts ""
      puts "*******************************************************************"
      puts "* Successfully generated the TX ADDR FIFO LogiCORE: $params(INSTANCE)"
      puts "*  - copied to ./implementation/$params(INSTANCE)_wrapper/"
      puts "*******************************************************************"
      puts ""
	  file del $cg_projdir/coregen.cgc
    } else {
      puts "$params(INSTANCE): ERROR - TX ADDR FIFO Core Generation Failed"
      puts ""
      puts $logfile "$params(INSTANCE): ERROR TX ADDR FIFO Core Generation Failed"
      puts ""
      puts $logfile ""
      close $logfile
  		return
    }
    
  }
  

  
    ##------GENERATE rx_fifo
   if {$params(C_RX_FIFO_KBYTE) == 0} {
      close $logfile
      return
 	 }
    
    
	  set rx_fifo_detect 0
	
	  if { [file exists $cg_projdir/rx_fifo.ngc] } {
	    puts "Detected rx_fifo.ngc"
	    puts $logfile "Detected rx_fifo.ngc"
	    if { [file exists $cg_projdir/$params(INSTANCE)_rx_fifo$params(C_RX_FIFO_KBYTE)k.arg] } {
	    	set rx_fifo_detect 1
	    }
	  }
	
	  if { $rx_fifo_detect == 1 } {
			file copy -force $cg_projdir/rx_fifo.ngc [pwd]/implementation/
	  }
	  if { $rx_fifo_detect == 0 } {
		  puts ""
		  puts "*******************************************************************"
		  puts "* $params(INSTANCE) : Generating RX FIFO LogiCORE"
		  puts "*******************************************************************"
		  puts ""
		  puts "  Param values are : $param_table"
		  puts ""
		  puts $logfile "**********************************************************"
		  puts $logfile "* $params(INSTANCE)"
		  puts $logfile "**********************************************************"
		
		  ############################################################################
		  # Write out a Core Generator arg file that matches
		  # the parameters set by the user.
		  ############################################################################
		
		  set filename "$cg_projdir/$params(INSTANCE)_rx_fifo$params(C_RX_FIFO_KBYTE)k.arg"
		  set argfile [open $filename "w"]
		
		  #must be for any fifo
#		  puts $argfile "NEWPROJECT $cg_projdir"
#		  puts $argfile "SETPROJECT $cg_projdir"
#			puts $argfile "# BEGIN Project Options"
#			puts $argfile "SET addpads = False"
#			puts $argfile "SET asysymbol = False"
#			puts $argfile "SET busformat = BusFormatAngleBracketNotRipped"
#			puts $argfile "SET createndf = False"
#			puts $argfile "SET designentry = VHDL"
#		  switch $params(C_FAMILY) {
#		    "spartan3e" {
#		      puts $argfile "SET device = xc3s500e"
#					puts $argfile "SET devicefamily = spartan3e"
#		    }
#		    "spartan3" {
#		      puts $argfile "SET device = xc3s400"
#					puts $argfile "SET devicefamily = spartan3"
#		    }
#		    "spartan3adsp" {
#		      puts $argfile "SET device = xc3sd1800a"
#					puts $argfile "SET devicefamily = spartan3adsp"
#		    } 
#                    "spartan6" {
#                      puts $argfile "SET device = xc6slx25"
#			                puts $argfile "SET devicefamily = spartan6"
#                   } 
#		    default {
#		      puts "ERROR:invalid family $params(C_FAMILY)!!"
#		    } 
#		  }
#			puts $argfile "SET flowvendor = Foundation_iSE"
#			puts $argfile "SET formalverification = False"
#			puts $argfile "SET foundationsym = False"
#			puts $argfile "SET implementationfiletype = Ngc"
#			switch $params(C_FAMILY) {
#                    "spartan6" {
#                      puts $argfile "SET package = ftg256"
#                      puts $argfile "SET speedgrade = -3"
#                    } 
#		    "spartan3adsp" {
#		      puts $argfile "SET package = fg676"
#			puts $argfile "SET speedgrade = -4"
#		    } 
#		    default {
#		      puts $argfile "SET package = pq208"
#			puts $argfile "SET speedgrade = -4"
#		    } 
#		  }
#			puts $argfile "SET removerpms = False"
#			puts $argfile "SET simulationfiles = Behavioral"
#			puts $argfile "SET verilogsim = True"
#			puts $argfile "SET vhdlsim = True"
#			puts $argfile "# END Project Options"
			
			puts $argfile "# BEGIN Select"
			puts $argfile "SELECT Fifo_Generator family Xilinx,_Inc. 7.2"
			puts $argfile "# END Select"
			puts $argfile "# BEGIN Parameters"
			puts $argfile "CSET almost_empty_flag=false"
			puts $argfile "CSET almost_full_flag=true"
			puts $argfile "CSET component_name=rx_fifo"
			puts $argfile "CSET data_count=false"
			puts $argfile "CSET data_count_width=12"
			puts $argfile "CSET dout_reset_value=0"
			puts $argfile "CSET empty_threshold_assert_value=4"
			puts $argfile "CSET empty_threshold_negate_value=5"
			puts $argfile "CSET enable_ecc=false"
#			puts $argfile "CSET enable_int_clk=false"
			puts $argfile "CSET fifo_implementation=Independent_Clocks_Block_RAM"
			puts $argfile "CSET full_flags_reset_value=0"
			puts $argfile "CSET full_threshold_assert_value=2047"
			puts $argfile "CSET full_threshold_negate_value=2046"
			puts $argfile "CSET input_data_width=8"
			puts $argfile "CSET input_depth=2048"
			puts $argfile "CSET output_data_width=32"
			puts $argfile "CSET output_depth=512"
			puts $argfile "CSET overflow_flag=true"
			puts $argfile "CSET overflow_sense=Active_High"
			puts $argfile "CSET performance_options=First_Word_Fall_Through"
			puts $argfile "CSET programmable_empty_type=No_Programmable_Empty_Threshold"
			puts $argfile "CSET programmable_full_type=No_Programmable_Full_Threshold"
			puts $argfile "CSET read_clock_frequency=1"
			puts $argfile "CSET read_data_count=true"
			puts $argfile "CSET read_data_count_width=10"
			puts $argfile "CSET reset_pin=true"
			puts $argfile "CSET reset_type=Asynchronous_Reset"
			puts $argfile "CSET underflow_flag=true"
			puts $argfile "CSET underflow_sense=Active_High"
			puts $argfile "CSET use_dout_reset=true"
			puts $argfile "CSET use_embedded_registers=false"
			puts $argfile "CSET use_extra_logic=true"
			puts $argfile "CSET valid_flag=true"
			puts $argfile "CSET valid_sense=Active_High"
			puts $argfile "CSET write_acknowledge_flag=false"
			puts $argfile "CSET write_acknowledge_sense=Active_High"
			puts $argfile "CSET write_clock_frequency=1"
			puts $argfile "CSET write_data_count=false"
			puts $argfile "CSET write_data_count_width=12"
			puts $argfile "# END Parameters"
			puts $argfile "GENERATE"

	
	   close $argfile
		
	
	  ############################################################################
	  # Call Core Generator with the arg file to create
	  # the core netlist in <proj>/implementation/CORE_INSTANCENAME/.
	  # Platgen will run ngcbuild from this location to merge the netlists
	  # into a single NGC file. This helps in case of multiple instantiations
	  # of the same core.
	  ############################################################################
	
	  puts "  $params(INSTANCE) : Running Core Generator to generate FIFO."
	  puts "    * This will take several minutes. . ."
	  puts ""
	  puts $logfile "$params(INSTANCE) : Running Core Generator to generate RX FIFO. . ."
	  file mkdir $cg_projdir
	  catch { exec coregen -p $projectfilename -b $filename } msg

    if { [file exists $cg_projdir/rx_fifo.ngc] } {
			file copy -force $cg_projdir/rx_fifo.ngc [pwd]/implementation/
      puts ""
      puts "*******************************************************************"
      puts "* Successfully generated the RX FIFO LogiCORE: $params(INSTANCE)"
      puts "*  - copied to ./implementation/$params(INSTANCE)_wrapper/"
      puts "*******************************************************************"
      puts ""
	  file del $cg_projdir/coregen.cgc
    } else {
      puts "$params(INSTANCE): ERROR - RX FIFO Core Generation Failed"
      puts ""
      puts $logfile "$params(INSTANCE): ERROR RX FIFO Core Generation Failed"
      puts ""
      puts $logfile ""
      close $logfile
  		return
    }
    
  }

  
  close $logfile
  
  return

}

