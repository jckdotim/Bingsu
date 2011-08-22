OSTYPE := $(shell uname -s)

SRC_FILES = \
	main.cpp \
	SceneDrawer.cpp \
	kbhit.cpp \
	signal_catch.cpp

INC_DIRS += /usr/include/nite /usr/include/ni
INC_DIRS += ./

EXE_NAME = BingsuS

DEFINES = USE_GLUT

ifeq ("$(OSTYPE)","Darwin")
        LDFLAGS += -framework OpenGL -framework GLUT
else
        USED_LIBS += glut
endif

BIN_DIR = ./bin

USED_LIBS += OpenNI XnVNite_1_3_1

# some defaults
ifndef INTEL_COMPILER
	INTEL_COMPILER = 0
endif

ifndef SSE_GENERATION
	SSE_GENERATION = 3
endif

ifndef CFG
	CFG = Release
endif

ifndef TARGET_SYS_ROOT
	TARGET_SYS_ROOT = /
endif

ifndef CROSS_PLATFORM
	CROSS_PLATFORM = 0
endif

# tool chain
ifeq ($(CROSS_PLATFORM), 1)
	CC = i686-cm-linux-g++
	AR = i686-cm-linux-ar -cqs
else
	ifeq ($(INTEL_COMPILER), 1)
		CC = icpc
	else
		CC = g++
	endif
	AR = ar -cqs
endif

RM = rm -rf
CP = cp

# expand file list
SRC_FILES_LIST = $(wildcard $(SRC_FILES))

OSTYPE := $(shell uname -s)

# change c struct alignment options to be compatable with Win32
ifneq ("$(OSTYPE)","Darwin")
	CFLAGS += -malign-double
else
	CFLAGS += -arch i386 -arch x86_64
	LDFLAGS += -arch i386 -arch x86_64
endif

# tell compiler to use the target system root
ifneq ("$(TARGET_SYS_ROOT)","/")
	CFLAGS += --sysroot=$(TARGET_SYS_ROOT)
	LDFLAGS += --sysroot=$(TARGET_SYS_ROOT)
endif

# define the intermediate directory
INT_DIR = $(CFG)

# define output directory
OUT_DIR = $(BIN_DIR)

# define a function to figure .o file for each source file (placed under intermediate directory)
SRC_TO_OBJ = $(addprefix ./$(INT_DIR)/,$(addsuffix .o,$(notdir $(basename $1))))

# create a list of all object files
OBJ_FILES = $(call SRC_TO_OBJ,$(SRC_FILES_LIST))

# define a function to translate any source file to its dependency file
SRC_TO_DEP = $(addprefix ./$(INT_DIR)/,$(addsuffix .d,$(notdir $(basename $1))))

# create a list of all dependency files
DEP_FILES = $(call SRC_TO_DEP,$(SRC_FILES_LIST))

# append the -I switch to each include directory
INC_DIRS_OPTION = $(foreach dir,$(INC_DIRS),-I$(dir))

# append the -L switch to each library directory
LIB_DIRS_OPTION = $(foreach dir,$(LIB_DIRS),-L$(dir)) -L$(OUT_DIR)

# append the -l switch to each library used
USED_LIBS_OPTION = $(foreach lib,$(USED_LIBS),-l$(lib))

# create -r option to mcs
USED_NETLIBS_OPTION = $(foreach lib,$(USED_LIBS),-r:$(lib).dll)

ifeq "$(NET_WIN_FORMS)" "1"
	USED_NETLIBS_OPTION += -r:System.Windows.Forms.dll -r:System.Drawing.dll
endif

DEFINES += XN_SSE
# append the -D switch to each define
DEFINES_OPTION = $(foreach def,$(DEFINES),-D$(def))

# some lib / exe specifics
ifneq "$(LIB_NAME)" ""
	CFLAGS += -fPIC -fvisibility=hidden
	ifneq ("$(OSTYPE)","Darwin")
		OUTPUT_NAME = lib$(LIB_NAME).so
		OUTPUT_COMMAND = $(CC) -o $(OUTPUT_FILE) $(OBJ_FILES) $(LDFLAGS) -shared
	else
		OUTPUT_NAME = lib$(LIB_NAME).dylib
		OUTPUT_COMMAND = $(CC) -o $(OUTPUT_FILE) $(OBJ_FILES) $(LDFLAGS) -dynamiclib -headerpad_max_install_names
	endif
endif
ifneq "$(EXE_NAME)" ""
	OUTPUT_NAME = $(EXE_NAME)
	OUTPUT_COMMAND = $(CC) -o $(OUTPUT_FILE) $(OBJ_FILES) $(LDFLAGS)
endif
ifneq "$(SLIB_NAME)" ""
	OUTPUT_NAME = lib$(SLIB_NAME).a
	OUTPUT_COMMAND = $(AR) $(OUTPUT_FILE) $(OBJ_FILES)
endif
ifneq "$(NETLIB_NAME)" ""
	OUTPUT_NAME = $(NETLIB_NAME).dll
	OUTPUT_COMMAND = gmcs -out:$(OUTPUT_FILE) -target:library $(CSFLAGS) $(USED_NETLIBS_OPTION) $(SRC_FILES)
	NET = 1
endif
ifneq "$(NETEXE_NAME)" ""
	OUTPUT_NAME = $(NETEXE_NAME).exe
	OUTPUT_COMMAND = gmcs -out:$(OUTPUT_FILE) -target:winexe $(CSFLAGS) $(USED_NETLIBS_OPTION) -r:$(OUT_DIR)/XnVNite.net_1_3_1.dll $(SRC_FILES)
	NET = 1
endif

# full path to output file
OUTPUT_FILE = $(OUT_DIR)/$(OUTPUT_NAME)

# set Debug / Release flags
ifeq "$(CFG)" "Debug"
	CFLAGS += -g
	ifeq ($(SSE_GENERATION), 2)
                CFLAGS += -msse2
        else
                ifeq ($(SSE_GENERATION), 3)
                        CFLAGS += -msse3 -mssse3 -mpc80
                else
                        ($error "Only SSE2 and SSE3 are supported")
                endif
        endif

endif
ifeq "$(CFG)" "Release"
#	CFLAGS += -O2 -fno-tree-pre -fno-strict-aliasing
	CFLAGS += -O3 -fno-tree-pre -fno-strict-aliasing
	CFLAGS += -DNDEBUG

	ifeq ($(SSE_GENERATION), 2)
		CFLAGS += -msse2
	else
		ifeq ($(SSE_GENERATION), 3)
			CFLAGS += -msse3 -mssse3
		else
			($error "Only SSE2 and SSE3 are supported")
		endif
	endif
	CSFLAGS += -o+
endif

CFLAGS += $(INC_DIRS_OPTION) $(DEFINES_OPTION)
LDFLAGS += $(LIB_DIRS_OPTION) $(USED_LIBS_OPTION)

# define a function that takes a source file and creates targets matching to it
ifeq "$(NET)" "1"
define CREATE_SRC_TARGETS
$(call SRC_TO_OBJ,$1) : $1 | $(INT_DIR)
	touch $(call SRC_TO_OBJ,$1)
endef
else
define CREATE_SRC_TARGETS
# create a target for the object file
$(call SRC_TO_OBJ,$1) : $1 | $(INT_DIR)
	$(CC) -c $(CFLAGS) -o $$@ $$<

# create a target for its dependency file
ifneq ("$(OSTYPE)","Darwin")
$(call SRC_TO_DEP,$1) : $1 | $(INT_DIR)
	$(CC) $(CFLAGS) -M -MF $$@ -MT "$(call SRC_TO_OBJ,$1) $$@" $1
else
endif
endef
endif
#############################################################################
# Targets
#############################################################################
.PHONY: all clean

# define the target 'all' (it is first, and so, default)
all: $(OUTPUT_FILE)

# Intermediate directory
$(INT_DIR):
	mkdir -p $(INT_DIR)

# create targets for each source file
$(foreach src,$(SRC_FILES_LIST),$(eval $(call CREATE_SRC_TARGETS,$(src))))

# include all dependency files
-include $(DEP_FILES)

# Output directory
$(OUT_DIR):
	mkdir -p $(OUT_DIR)

# Final output file
$(OUTPUT_FILE): $(OBJ_FILES) | $(OUT_DIR)
	$(OUTPUT_COMMAND)

clean:
	$(RM) $(OUTPUT_FILE) $(OBJ_FILES) $(DEP_FILES)
	
