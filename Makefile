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
LDLIBS = -lm -lgba -lmruby
LDFLAGS = -mthumb-interwork -mthumb -specs=gba.specs \
					-L /opt/devkitpro/libgba/lib/ \
					-L ./vendor/mruby-2.1.1/build/gameboyadvance/lib
CFLAGS = -std=c++17 \
				 -pedantic-errors -Wall -Weffc++ -Wextra -Wsign-conversion \
				 -mthumb-interwork -mthumb \
				 -isystem /opt/devkitpro/libgba/include \
				 -isystem ./vendor/mruby-2.1.1/include
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

$$($(1)_ELF): $$($(1)_OBJS) vendor/mruby-2.1.1/build/gameboyadvance/lib/libmruby.a
	$$(CC) $$(LDFLAGS) $$($(1)_OBJS) $$(LDLIBS) -o $$@

$$($(1)_DIR)/%.o: $$(SRC_DIR)/%.c | $$($(1)_DIR) vendor/mruby-2.1.1
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

#
# Vendor
#
vendor_clean:
	rm -r vendor

.PHONY: vendor_clean

# | means an "order-only" prerequisite. Basically it lets me use a directory as
# a dependency in a way that doesn't cause extra rebuilds.
# https://stackoverflow.com/a/4481931
# https://www.gnu.org/software/make/manual/make.html#Prerequisite-Types
vendor/mruby-2.1.1/build/gameboyadvance/lib/libmruby.a: mruby_build_config.rb | vendor/mruby-2.1.1
	cd ./vendor/mruby-2.1.1 && rake

vendor/mruby-2.1.1: vendor/mruby-2.1.1.zip
	unzip ./vendor/mruby-2.1.1.zip -d ./vendor/
	rm ./vendor/mruby-2.1.1/build_config.rb
	cd ./vendor/mruby-2.1.1 && ln -s ../../mruby_build_config.rb build_config.rb

vendor/mruby-2.1.1.zip: | vendor
	wget -O ./vendor/mruby-2.1.1.zip https://github.com/mruby/mruby/archive/2.1.1.zip

vendor:
	mkdir -p vendor
