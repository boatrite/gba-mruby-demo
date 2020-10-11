#
# Project
#
BUILD_DIR = build

SRC_DIR = src
SRCS = main.c
OBJS = $(SRCS:.c=.o)

all: gba_release gba_debug

test: vba_release vba_debug

clean:
	rm -r $(BUILD_DIR)

.PHONY: all test clean

# Make `source` command available.
SHELL := /bin/bash
# Set the paths to the gba toolchain binaries
ENV := source /etc/profile.d/devkit-env.sh && export PATH=/opt/devkitpro/devkitARM/bin:$$PATH
CC := $(ENV) && arm-none-eabi-g++
OBJCOPY := $(ENV) && arm-none-eabi-objcopy
LDLIBS = -lm -lgba
LDFLAGS = -mthumb-interwork -mthumb -specs=gba.specs \
					-L /opt/devkitpro/libgba/lib/
CFLAGS = -std=c++17 \
				 -pedantic-errors -Wall -Weffc++ -Wextra -Wsign-conversion \
				 -mthumb-interwork -mthumb \
				 -isystem /opt/devkitpro/libgba/include
REL_CFLAGS = -O3 -DNDEBUG
DBG_CFLAGS = -g -O0 -DNDEBUG=0

#
# Build Template
#
ELF = main.elf
ROM = main.gba
define gba_build_template
$(1)_DIR = $$(BUILD_DIR)/gba_$(2)
$(1)_ELF = $$($(1)_DIR)/$$(ELF)
$(1)_ROM = $$($(1)_DIR)/$$(ROM)
$(1)_OBJS = $$(addprefix $$($(1)_DIR)/, $$(OBJS))

vba_$(2): $$($(1)_ROM)
	vba $$<

gba_$(2): $$($(1)_ROM)

.PHONY: vba_$(2) gba_$(2)

$$($(1)_ROM): $$($(1)_ELF)
	$$(OBJCOPY) -v -O binary $$< $$@ && gbafix $$@

$$($(1)_ELF): $$($(1)_OBJS)
	$$(CC) $$(LDFLAGS) $$($(1)_OBJS) $$(LDLIBS) -o $$@

$$($(1)_DIR)/%.o: $$(SRC_DIR)/%.c | $$($(1)_DIR)
	$$(CC) -c $$(CFLAGS) $$($(1)_CFLAGS) -o $$@ $$<

$$($(1)_DIR):
	mkdir -p $$@

endef

#
# Builds
#
$(eval $(call gba_build_template,DBG,debug))
$(eval $(call gba_build_template,REL,release))

info:
	$(info $(call gba_build_template,DBG,debug))
	$(info $(call gba_build_template,REL,release))

.PHONY: gba_info
