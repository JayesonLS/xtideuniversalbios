###############################################################################
# Generic makefile for building binary files.                                 #
# v. 1.1.0 (28.7.2007 ... 5.10.2010)                                          #
# (C) Tomi Tilli                                                              #
# aitotat@gmail.com                                                           #
#                                                                             #
# Valid makefile targets are:                                                 #
# all		Removes existing files and builds binary file in \Build           #
# build		Builds binary file in \Build                                      #
# clean		Removes all files from \Build                                     #
#                                                                             #
# Build directory must be created manually if it does not exist.              #
#                                                                             #
###############################################################################

###########################################
# Source files and destination executable #
###########################################

# Assembly source code file (*.asm):
SRC_ASM = Src/Main.asm

# Program executable file name without extension:
PROG = xtidecfg
EXTENSION = com


#######################################
# Destination and include directories #
#######################################

# Directory where binary file will be compiled to
BUILD_DIR = Build

# Subdirectories where included files are:
HEADERS = Inc/
HEADERS += Inc/Help/
HEADERS += Src/
HEADERS += Src/Menupages/

# Subdirectories where library files are:
LIBS = ../Assembly_Library/Inc/
LIBS += ../Assembly_Library/Src/
LIBS += ../Assembly_Library/Src/Display/
LIBS += ../Assembly_Library/Src/File/
LIBS += ../Assembly_Library/Src/Keyboard/
LIBS += ../Assembly_Library/Src/Menu/
LIBS += ../Assembly_Library/Src/Menu/Dialog/
LIBS += ../Assembly_Library/Src/String/
LIBS += ../Assembly_Library/Src/Time/
LIBS += ../Assembly_Library/Src/Util/
LIBS += ../XTIDE_Universal_BIOS/Inc/
HEADERS += $(LIBS)



#################################################################
# Assembler preprocessor defines.                               #
#################################################################
DEFINES = 
DEFINES_XT = ELIMINATE_CGA_SNOW
DEFINES_XTPLUS = USE_186 ELIMINATE_CGA_SNOW
DEFINES_AT = USE_186 USE_286 USE_AT


###################
# Other variables #
###################

# Add -D in front of every preprocessor define declaration
DEFS = $(DEFINES:%=-D%)
DEFS_XT = $(DEFINES_XT:%=-D%)
DEFS_XTPLUS = $(DEFINES_XTPLUS:%=-D%)
DEFS_AT = $(DEFINES_AT:%=-D%)

# Add -I in front of all header directories
IHEADERS = $(HEADERS:%=-I%)

# Path + target file to be build
TARGET = $(BUILD_DIR)/$(PROG)


#########################
# Compilers and linkers #
#########################

# Make
MAKE = mingw32-make.exe

# Assembler
AS = yasm.exe
#AS = nasm.exe

# use this command to erase files.
RM = -del /Q


#############################
# Compiler and linker flags #
#############################

# Assembly compiler flags
ASFLAGS = -f bin				# Produce binary object files
ASFLAGS += $(DEFS)				# Preprocessor defines
ASFLAGS += $(IHEADERS)			# Set header file directory paths
ASFLAGS += -Worphan-labels		# Warn about labels without colon
ASFLAGS += -O9					# Optimize operands to their shortest forms


############################################
# Build process. Actual work is done here. #
############################################

.PHONY: all at xtplus xt clean

# Make clean debug and release versions
all: clean xt
	@echo All build!

at:
	@$(AS) "$(SRC_ASM)" $(ASFLAGS) $(DEFS_AT) -o"$(TARGET)_at.$(EXTENSION)"
	@echo AT version "$(TARGET)_at.$(EXTENSION)" build.

xtplus:
	@$(AS) "$(SRC_ASM)" $(ASFLAGS) $(DEFS_XTPLUS) -o"$(TARGET)_xtp.$(EXTENSION)"
	@echo XT plus version "$(TARGET)_xtp.$(EXTENSION)" build.

xt:
	@$(AS) "$(SRC_ASM)" $(ASFLAGS) $(DEFS_XT) -o"$(TARGET).$(EXTENSION)"
	@echo XT version "$(TARGET).$(EXTENSION)" build.

clean:
	@$(RM) $(BUILD_DIR)\*.*
	@echo Deleted "(*.*)" from "$(BUILD_DIR)/"
