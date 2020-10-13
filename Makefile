#
# Project
#
BUILD_DIR = build
SCRIPT_DIR = scripts
SCRIPTS = ruby_main.rb
SCRIPT_BYTECODE_DIR = $(BUILD_DIR)/bytecode

SRC_DIR = src
SRCS = main.c $(SCRIPTS:.rb=.c)
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

flash_$(2): flasher/config-flash.ini $$($(1)_ROM)
	cd flasher/ && sudo ./GBxCart_RW_Flasher_v1.37/GBxCart_RW_Console_Flasher_v1.37/gbxcart_rw_flasher_v1.37 ../$$($(1)_ROM)

.PHONY: vba_$(2) gba_$(2) flash_$(2)

$$($(1)_ROM): $$($(1)_ELF)
	$$(OBJCOPY) -v -O binary $$< $$@ && gbafix $$@

$$($(1)_ELF): $$($(1)_OBJS) vendor/mruby-2.1.1/build/gameboyadvance/lib/libmruby.a
	$$(CC) $$(LDFLAGS) $$($(1)_OBJS) $$(LDLIBS) -o $$@

$$($(1)_DIR)/%.o: $$(SRC_DIR)/%.c | $$($(1)_DIR) vendor/mruby-2.1.1
	$$(CC) -c $$(CFLAGS) $$($(1)_CFLAGS) -o $$@ $$<

$$($(1)_DIR)/%.o: $$(SCRIPT_BYTECODE_DIR)/%.c | $$($(1)_DIR) vendor/mruby-2.1.1
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
# Scripting
#
$(SCRIPT_BYTECODE_DIR)/%.c: $(SCRIPT_DIR)/%.rb | $(SCRIPT_BYTECODE_DIR)
	./vendor/mruby-2.1.1/bin/mrbc -B$(patsubst $(SCRIPT_BYTECODE_DIR)/%.c,%,$@) -o $@ $<

# Keep bytecode files after task runs. These are normally deleted since they
# are identified as intermediary.
.PRECIOUS: $(SCRIPT_BYTECODE_DIR)/%.c

$(SCRIPT_BYTECODE_DIR):
	mkdir -p $@

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

#
# Flashcart tools
#
# Note: flash_release and flash_debug are defined dynamically above which
# perform the actual flashing.
#
flasher_clean:
	rm -f flasher/config.ini
	rm -r flasher

.PHONY: flasher_clean

# We need to run the flasher without any arguments once in order to configure it
flasher/config-flash.ini: flasher/GBxCart_RW_Flasher_v1.37/GBxCart_RW_Console_Flasher_v1.37/gbxcart_rw_flasher_v1.37
	cd flasher/ && ./GBxCart_RW_Flasher_v1.37/GBxCart_RW_Console_Flasher_v1.37/gbxcart_rw_flasher_v1.37

flasher/GBxCart_RW_Flasher_v1.37/GBxCart_RW_Console_Flasher_v1.37/gbxcart_rw_flasher_v1.37: | flasher/GBxCart_RW_Flasher_v1.37
	cd flasher/GBxCart_RW_Flasher_v1.37/GBxCart_RW_Console_Flasher_v1.37/ && make

flasher/GBxCart_RW_Flasher_v1.37: flasher/GBxCart_RW_Flasher_v1.37.zip
	unzip ./flasher/GBxCart_RW_Flasher_v1.37.zip -d ./flasher/

flasher/GBxCart_RW_Flasher_v1.37.zip: | flasher
	wget -O flasher/GBxCart_RW_Flasher_v1.37.zip https://shop.insidegadgets.com/wp-content/uploads/2018/05/GBxCart_RW_Flasher_v1.37.zip

flasher:
	mkdir -p flasher
