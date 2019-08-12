ORBTrace Development
====================

his is the development status for the ORBTrace parallel TRACE hardware. It is working but it's fragile and incomplete. It may well eat your cat.  Its very unlikely you want to be here but, just in case you do, this is built using Clifford Wolfs' icestorm toolchain and currently targets a either a lattice iCE40HX-8K board or the lattice icestick.

It is very much work in progress. It is functional for 1, 2 and 4 bit trace widths, but only for the HX8 board at the moment. It also integrates BlackMesaLabs SUMP2 and BlackMagic Probe.


To build it perform;

```
cd src
make ICE40HX8K_B_EVN

```

The pinouts are;

# Trace signals
traceDin[0]	C16	# J2 pin 37
traceDin[1]	D16	# J2 pin 35
traceDin[2]	E16	# J2 pin 33
traceDin[3]	F16	# J2 pin 29
traceClk	H16	# J2 pin 25

# SWD connections
swdpin           D14      # SWD io
swdclkpin        B16      # SWD Clk

The LEDs show the following things;

Trace Sync       LED0 (D9, red)
Trace Overflow   LED1 (D8, red)
Transmission     LED2 (D7, red)
Heartbeat        LED3 (D6, red)

There are a number of other pins defined, you can see them in the pcf file in the source directory.  By default the sump2 pins are allocated to internal signals, but they can be re-allocated to external pins in the pcf.

When you start this version of orbuculum it will start a BlackMagic Probe service at localhost:2000 which you can connect to using;

`gdb>target extended-remote localhost:2000`

Once again, this is incomplete and functionally dodgy. Use at your own risk!!


Porting to Zynq
===============

Orbtrace is being ported to Zynq architecture and plan is to support Zedboard and Zybo development kits for now, both of them are based on the same 7z020 parts. The directory tree of the project was changed a bit to minimize repeated code. Also, implementation scripts compatible with Xilinx tools are under development, plans are to make it compatible with Make tools.


Directory structure
-------------------

A `target` directory was created to hold files specific to boards, such as constraints. In that folder, there is a `config.tcl` file that provides information needed by the implementation scripts. Inside `src` folder, a `arch` directory was created for files needed by a specific chip. Arch and target names are likely to change in the near future.


Implementing the code
---------------------

A `tcl` library (for Xilinx's sake) was written to simplify the instructions (and how it is inserted) in the `config.tcl` file. The only other important file for users is the `build.sh` wrapper (which will call the work horse `build.tcl` script file). Assuming the command line prompt isTo compile the code, the following command should be used: 

  ```sh
  bash <orbtrace folder>/tools/build.sh <Vivado path> <target folder>
  ```

For example, if I am in the `orbuculum/orbtrace` directory, if I have Vivado 2018.3 installed in my system in the `opt/Xilinx/2018.3` folder and if I want to implement the zedboard target (the only available right now x):

  ```sh
  bash tools/build.sh /opt/Xilinx/Vivado/2018.3 target/zedboard
  ```

NB: It should not matter where in the directory tree the commands above are issued.

NB: The full implementation flow is available in the `build.tcl` file, but it is commented out since we are in the early stages of the porting.


Shortcomings
------------

- No constraint file included yet.
