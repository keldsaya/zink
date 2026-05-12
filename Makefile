VERSION = 0
PATCHLEVEL = 0
SUBLEVEL = 1
EXTRAVERSION = -rc1
NAME = Program

PROGRAMVERSION = $(VERSION)$(if $(PATCHLEVEL),.$(PATCHLEVEL)$(if $(SUBLEVEL),.$(SUBLEVEL)))$(EXTRAVERSION)
VERSIONSTR = $(PROGRAMVERSION) ($(NAME))

HOSTCC   := gcc
HOSTCFLAGS := -Wall -Wextra
HOSTLD   := $(HOSTCC)

CC       := gcc
CFLAGS   := -Wall -Wextra -Iinclude
LDFLAGS  :=
LD       := $(CC)

-include local.mk

DEPFLAGS = -MMD -MP -MF $(@:.o=.d)
HOSTDEPFLAGS = -MMD -MP -MF $(@:.host.o=.d)

BUILD    := build
OUTPUT   := $(BUILD)/program

KBUILD_INCLUDES := build/generated/objs.mk

SHELL := /bin/bash

# Генерация objs.mk - НЕ зависит от .config чтобы избежать цикла
$(KBUILD_INCLUDES): $(shell find . -name Makefile 2>/dev/null)
	@mkdir -p build/generated
	@bash scripts/zbuild/parse.sh .config

-include $(KBUILD_INCLUDES)

DEPS := $(OBJS:.o=.d) $(HOSTOBJS:.o=.d)
-include $(DEPS)

define get_prog_objs =
$(filter $(dir $(1))%.o,$(HOSTOBJS))
endef

define hostprogs_rule =
$(1): $(call get_prog_objs,$(1))
	@echo "  HOSTLD  $$@"
	@mkdir -p $$(dir $$@)
	@$(HOSTLD) $$^ -o $$@

$(notdir $(1)): $(1)
	@$$<
endef

$(foreach prog,$(HOSTPROGS),$(eval $(call hostprogs_rule,$(prog))))

MAKEFLAGS += --no-print-directory

all: include/version.h $(OUTPUT)
	@:

%config: scripts/zconfig/entry.sh
	@if [ -f "$@" ] && [ "$@" != "defconfig" ] && [ "$@" != "oldconfig" ] && [ "$@" != "savedefconfig" ]; then \
	else \
		bash scripts/zconfig/entry.sh --$@; \
	fi

.PHONY: defconfig oldconfig savedefconfig
defconfig oldconfig savedefconfig: scripts/zconfig/entry.sh
	@bash scripts/zconfig/entry.sh --$@

.config: Zconfig scripts/zconfig/entry.sh 
	@bash scripts/zconfig/entry.sh --defconfig

include/config.h: .config scripts/zconfig/entry.sh
	@mkdir -p include
	@bash scripts/zconfig/entry.sh --header

include/version.h: scripts/version.sh
	@mkdir -p include
	@bash scripts/version.sh $(VERSION) $(PATCHLEVEL) $(SUBLEVEL) $(EXTRAVERSION) "$(NAME)" $@

$(OUTPUT): $(OBJS)
	@echo "  LD    $(OUTPUT)"
	@mkdir -p $(BUILD)
	@$(CC) $(LDFLAGS) $(OBJS) -o $(OUTPUT)

$(BUILD)/%.o: %.c include/config.h include/version.h
	@echo "  CC    $<"
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) $(DEPFLAGS) -c $< -o $@

$(BUILD)/%.host.o: %.c
	@echo "  HOSTCC  $<"
	@mkdir -p $(dir $@)
	@$(HOSTCC) $(HOSTCFLAGS) $(HOSTDEPFLAGS) -c $< -o $@

run: all
	@echo "  RUN   $(OUTPUT)"
	@$(OUTPUT)

clean:
	@echo "  CLN   build/"
	@rm -rf $(BUILD)
	@echo "  CLN   .config"
	@rm -rf .config
	@echo "  CLN   include/version.h"
	@rm -rf include/version.h
	@echo "  CLN   include/config.h"
	@rm -rf include/config.h

help:
	@echo "Targets:"
	@echo "  all        - build project"
	@echo "  clean      - remove build/"
	@echo "  run        - run executable"
	@echo "  mconfig    - run menu config"
	@echo "  defconfig  - generate .config"
	@echo "  oldconfig  - update .config"
	@echo "  savedefconfig - save minimal defconfig"
	@echo "  help       - show help"

.DEFAULT_GOAL := all

.PHONY: all clean run help mconfig
