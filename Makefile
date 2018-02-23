#VERBOSE=1
DEBUG=1
WITH_FPGA=1

CFLAGS=-DVERSION="\"0.30\""

CROSS_COMPILE=
# Output Files
ORBUCULUM = orbuculum
ORBCAT = orbcat
ORBTOP = orbtop
ORBDUMP = orbdump
ORBSTAT = orbstat

##########################################################################
# Check Host OS
##########################################################################

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
  CFLAGS += -DLINUX
  LINUX=1
endif
ifeq ($(UNAME_S),Darwin)
  CFLAGS += -DOSX
  OSX=1
endif

##########################################################################
# User configuration and firmware specific object files	
##########################################################################

# Overall system defines for compilation
ifdef DEBUG
GCC_DEFINE= -DDEBUG_ON
OPT_LEVEL = 
else
GCC_DEFINE=
OPT_LEVEL = -O2
endif

GCC_DEFINE+= -std=gnu99

CFILES =
SFILES =
OLOC = ofiles
INCLUDE_PATHS = -I/usr/local/include/libusb-1.0 
LDLIBS = -L/usr/local/lib -lusb-1.0 -lelf -lbfd -lz -ldl -liberty

#ifdef LINUX
LDLIBS += -lpthread
#endif

ifdef WITH_FPGA
CFLAGS+=-DINCLUDE_FPGA_SUPPORT
LDLIBS += -lftdi1
endif

DEBUG_OPTS = -g3 -gdwarf-2 -ggdb

##########################################################################
# Generic multi-project files 
##########################################################################

##########################################################################
# Project-specific files 
##########################################################################

# Main Files
# ==========
App_DIR=Src
INCLUDE_PATHS += -IInc -I$(OLOC)

ORBUCULUM_CFILES = $(App_DIR)/$(ORBUCULUM).c $(App_DIR)/filewriter.c $(App_DIR)/ftdispi.c
ORBUCULUM_CFILES += $(App_DIR)/iceproglite.c

# BMP Component Files
# ===================
GCC_DEFINE+=-DBLACKORB -DPLATFORM_HAS_DEBUG
BMP_DIR=bmp
INCLUDE_PATHS += -I$(BMP_DIR)/include -I$(BMP_DIR)/target -I$(BMP_DIR)
INCLUDE_PATHS += -I$(BMP_DIR)/platforms/common -I$(BMP_DIR)/platforms/blackorb

ORBUCULUM_CFILES += $(BMP_DIR)/morse.c    $(BMP_DIR)/gdb_main.c    $(BMP_DIR)/exception.c
ORBUCULUM_CFILES += $(BMP_DIR)/platforms/common/timing.c   
ORBUCULUM_CFILES += $(BMP_DIR)/platforms/blackorb/platform.c
ORBUCULUM_CFILES += $(BMP_DIR)/platforms/blackorb/jtagtap.c   
ORBUCULUM_CFILES += $(BMP_DIR)/platforms/blackorb/gdb_if.c
ORBUCULUM_CFILES += $(BMP_DIR)/platforms/blackorb/swdptap_blackorb.c
ORBUCULUM_CFILES += $(BMP_DIR)/command.c
ORBUCULUM_CFILES += $(BMP_DIR)/gdb_packet.c
ORBUCULUM_CFILES += $(BMP_DIR)/gdb_hostio.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/efm32.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/target.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/nrf51.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/jtagtap_generic.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/stm32f1.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/lpc43xx.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/cortexa.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/sam4l.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/kinetis.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/adiv5_swdp.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/lpc15xx.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/cortexm.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/sam3x.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/adiv5.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/adiv5_jtagdp.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/stm32l0.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/samd.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/stm32l4.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/jtag_scan.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/lpc11xx.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/stm32f4.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/lpc_common.c
ORBUCULUM_CFILES += $(BMP_DIR)/target/lmi.c
ORBUCULUM_CFILES += $(BMP_DIR)/crc32.c
ORBUCULUM_CFILES += $(BMP_DIR)/hex_utils.c


#ORBUCULUM_CFILES += $(BMP_DIR)/target/flashstub/efm32.c
#ORBUCULUM_CFILES += $(BMP_DIR)/target/flashstub/nrf51.c
#ORBUCULUM_CFILES += $(BMP_DIR)/target/flashstub/stm32f1.c
#ORBUCULUM_CFILES += $(BMP_DIR)/target/flashstub/stm32f4_x8.c
#ORBUCULUM_CFILES += $(BMP_DIR)/target/flashstub/stm32f4_x32.c
#ORBUCULUM_CFILES += $(BMP_DIR)/target/flashstub/stm32l4.c
#ORBUCULUM_CFILES += $(BMP_DIR)/target/flashstub/lmi.c


ORBCAT_CFILES = $(App_DIR)/$(ORBCAT).c 
ORBTOP_CFILES = $(App_DIR)/$(ORBTOP).c $(App_DIR)/symbols.c 
ORBDUMP_CFILES = $(App_DIR)/$(ORBDUMP).c
ORBSTAT_CFILES = $(App_DIR)/$(ORBSTAT).c $(App_DIR)/symbols.c 

##########################################################################
# GNU GCC compiler prefix and location
##########################################################################

ASTYLE = astyle
AS = $(CROSS_COMPILE)gcc
CC = $(CROSS_COMPILE)gcc
LD = $(CROSS_COMPILE)gcc
GDB = $(CROSS_COMPILE)gdb
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump
GET_GIT_HASH = Tools/git_hash_to_c/git_hash_to_c.sh
MAKE = make

##########################################################################
# Quietening
##########################################################################

ifdef VERBOSE
cmd = $1
Q :=
else
cmd = @$(if $(value 2),echo "$2";)$1
Q := @
endif

HOST=-lc -lusb

##########################################################################
# Compiler settings, parameters and flags
##########################################################################
# filename for embedded git revision 
GIT_HASH_FILENAME=git_version_info.h

CFLAGS +=  $(ARCH_FLAGS) $(STARTUP_DEFS) $(OPT_LEVEL) $(DEBUG_OPTS) \
		-ffunction-sections -fdata-sections -Wall -Wno-unused-result $(INCLUDE_PATHS)  $(GCC_DEFINE)
ASFLAGS += -c $(DEBUG_OPTS) $(INCLUDE_PATHS) $(ARCH_FLAGS) $(GCC_DEFINE) \
          -x assembler-with-cpp
LDFLAGS += $(CFLAGS)

OCFLAGS += --strip-unneeded

# Generic Stuff
OBJS =  $(patsubst %.c,%.o,$(CFILES)) $(patsubst %.s,%.o,$(SFILES))
POBJS = $(patsubst %,$(OLOC)/%,$(OBJS))
PDEPS = $(POBJS:.o=.d)

# Per Target Stuff
ORBUCULUM_OBJS =  $(OBJS) $(patsubst %.c,%.o,$(ORBUCULUM_CFILES))
ORBUCULUM_POBJS = $(POJBS) $(patsubst %,$(OLOC)/%,$(ORBUCULUM_OBJS))
ORBUCULUM_PDEPS = $(PDEPS) $(ORBUCULUM_POBJS:.o=.d)

ORBCAT_OBJS =  $(OBJS) $(patsubst %.c,%.o,$(ORBCAT_CFILES))
ORBCAT_POBJS = $(POJBS) $(patsubst %,$(OLOC)/%,$(ORBCAT_OBJS))
ORBCAT_PDEPS = $(PDEPS) $(ORBCAT_POBJS:.o=.d)

ORBTOP_OBJS =  $(OBJS) $(patsubst %.c,%.o,$(ORBTOP_CFILES))
ORBTOP_POBJS = $(POJBS) $(patsubst %,$(OLOC)/%,$(ORBTOP_OBJS))
ORBTOP_PDEPS = $(PDEPS) $(ORBTOP_POBJS:.o=.d)

ORBDUMP_OBJS =  $(OBJS) $(patsubst %.c,%.o,$(ORBDUMP_CFILES))
ORBDUMP_POBJS = $(POJBS) $(patsubst %,$(OLOC)/%,$(ORBDUMP_OBJS))
ORBDUMP_PDEPS = $(PDEPS) $(ORBDUMP_POBJS:.o=.d)

ORBSTAT_OBJS =  $(OBJS) $(patsubst %.c,%.o,$(ORBSTAT_CFILES))
ORBSTAT_POBJS = $(POJBS) $(patsubst %,$(OLOC)/%,$(ORBSTAT_OBJS))
ORBSTAT_PDEPS = $(PDEPS) $(ORBSTAT_POBJS:.o=.d)

CFILES += $(App_DIR)/itmDecoder.c $(App_DIR)/tpiuDecoder.c $(App_DIR)/generics.c

##########################################################################
##########################################################################
##########################################################################

all : build 

get_version:
	$(Q)mkdir -p $(OLOC)
	$(Q)$(GET_GIT_HASH) > $(OLOC)/$(GIT_HASH_FILENAME)

$(OLOC)/%.o : %.c
	$(Q)mkdir -p $(basename $@)
	$(call cmd, \$(CC) -c $(CFLAGS) -MMD -o $@ $< ,\
	Compiling $<)

build: $(ORBUCULUM) $(ORBCAT) $(ORBTOP) $(ORBDUMP) $(ORBSTAT)

$(ORBUCULUM) : get_version $(ORBUCULUM_POBJS) $(SYS_OBJS)
	$(Q)$(LD) $(LDFLAGS) -o $(OLOC)/$(ORBUCULUM) $(MAP) $(ORBUCULUM_POBJS) $(LDLIBS)
	-@echo "Completed build of" $(ORBUCULUM)

$(ORBCAT) : get_version $(ORBCAT_POBJS) $(SYS_OBJS)
	$(Q)$(LD) $(LDFLAGS) -o $(OLOC)/$(ORBCAT) $(MAP) $(ORBCAT_POBJS) $(LDLIBS)
	-@echo "Completed build of" $(ORBCAT)

$(ORBTOP) : get_version $(ORBTOP_POBJS) $(SYS_OBJS)
	$(Q)$(LD) $(LDFLAGS) -o $(OLOC)/$(ORBTOP) $(MAP) $(ORBTOP_POBJS) $(LDLIBS)
	-@echo "Completed build of" $(ORBTOP)

$(ORBDUMP) : get_version $(ORBDUMP_POBJS) $(SYS_OBJS)
	$(Q)$(LD) $(LDFLAGS) -o $(OLOC)/$(ORBDUMP) $(MAP) $(ORBDUMP_POBJS) $(LDLIBS)
	-@echo "Completed build of" $(ORBDUMP)

$(ORBSTAT) : get_version $(ORBSTAT_POBJS) $(SYS_OBJS)
	$(Q)$(LD) $(LDFLAGS) -o $(OLOC)/$(ORBSTAT) $(MAP) $(ORBSTAT_POBJS) $(LDLIBS)
	-@echo "Completed build of" $(ORBSTAT)

tags:
	-@etags $(CFILES) 2> /dev/null

clean:
	-$(call cmd, \rm -f $(POBJS) $(LD_TEMP) $(ORBUCULUM) $(ORBCAT) $(ORBDUMP) $(ORBSTAT) $(OUTFILE).map $(EXPORT) ,\
	Cleaning )
	$(Q)-rm -rf SourceDoc/*
	$(Q)-rm -rf *~ core
	$(Q)-rm -rf $(OLOC)/*
	$(Q)-rm -rf config/*~
	$(Q)-rm -rf TAGS

$(generated_dir)/git_head_revision.c:
	mkdir -p $(dir $@)
	../Tools/git_hash_to_c.sh > $@    

doc:
	doxygen $(DOXCONFIG)

print-%:
	@echo $* is $($*)

pretty:
	$(Q)-$(ASTYLE) --options=config/astyle.conf "Inc/*.h" "Src/*.c"

-include $(PDEPS)
