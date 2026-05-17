VERSION = 0
PATCHLEVEL = 0
SUBLEVEL = 1
EXTRAVERSION = -rc1
NAME = Program

PROGRAMVERSION = $(VERSION)$(if $(PATCHLEVEL),.$(PATCHLEVEL)$(if $(SUBLEVEL),.$(SUBLEVEL)))$(EXTRAVERSION)

# tools
HOSTCC    := gcc
HOSTLD    := $(HOSTCC)
HOSTFLAGS := -Wall -Wextra

CC        := gcc
LD        := $(CC)
CFLAGS    := -Wall -Wextra -Iinclude
LDFLAGS   :=

ASM       := nasm
ASMFLAGS  :=
GASM      := $(CC)
GASMFLAGS :=

-include local.mk

# paths
BUILD     := build
DEPSDIR   := $(BUILD)/deps
OUTPUT    := $(BUILD)/program
OBJS_MK   := $(BUILD)/generated/objs.mk
CONFIG_H  := include/config.h
VERSION_H := include/version.h

# scripts
LOG       := scripts/log.sh
CLEAN_SH  := scripts/clean/entry.sh
CONFIG_SH := scripts/zconfig/entry.sh
PARSER_SH := scripts/zbuild/parse.sh
VERSION_SH := scripts/version.sh

DEPFLAGS     = -MMD -MP -MF $(DEPSDIR)/$(subst /,_,$*).d
HOSTDEPFLAGS = -MMD -MP -MF $(DEPSDIR)/$(subst /,_,$*).host.d

DEPFLAGS_ASM  = -MD -MF $(DEPSDIR)/$(subst /,_,$*).d
DEPFLAGS_GASM = -MMD -MP -MF $(DEPSDIR)/$(subst /,_,$*).d

SHELL     := /bin/sh
MAKEFLAGS += --no-print-directory

.DEFAULT_GOAL := all

ifeq ($(filter clean mrproper help defconfig oldconfig savedefconfig,$(MAKECMDGOALS)),)

.config: ./Zconfig scripts/zconfig/entry.sh
	@$(LOG) "GEN" ".config"
	@$(CONFIG_SH) --defconfig

$(OBJS_MK): .config scripts/zbuild/parse.sh
	@mkdir -p $(dir $(OBJS_MK))
	@$(PARSER_SH) .config

-include $(OBJS_MK)

DEPS := $(addprefix $(DEPSDIR)/,$(subst /,_,$(OBJS:.o=.d))) \
        $(addprefix $(DEPSDIR)/,$(subst /,_,$(HOSTOBJS:.host.o=.host.d)))
-include $(DEPS)

endif

# targets
all: $(CONFIG_H) $(VERSION_H) $(OUTPUT)

run: all
	@$(LOG) "RUN" "$(OUTPUT)"
	@$(OUTPUT)

clean:
	@$(CLEAN_SH) --base $(OUTPUT)

mrproper: clean
	@$(CLEAN_SH) --proper

help:
	@echo "Targets:"
	@echo "  all           build project"
	@echo "  clean         remove build/"
	@echo "  mrproper      remove build/ and .config"
	@echo "  run           run executable"
	@echo "  mconfig       run menu config"
	@echo "  defconfig     generate .config"
	@echo "  oldconfig     update .config"
	@echo "  savedefconfig save minimal defconfig"
	@echo "  help          show help"

.PHONY: all clean mrproper run help

# headers gen
$(CONFIG_H): .config scripts/zconfig/entry.sh
	@$(CONFIG_SH) --header

$(VERSION_H): scripts/version.sh
	@$(VERSION_SH) $(VERSION) $(PATCHLEVEL) $(SUBLEVEL) $(EXTRAVERSION) "$(NAME)" $@

%config: scripts/zconfig/entry.sh
	@case "$@" in \
		.config|Zconfig|mconfig) ;; \
		*/*|*.*) ;; \
		*) $(CONFIG_SH) --$@ ;; \
	esac

# compilation
$(OUTPUT): $(OBJS) $(CONFIG_H) $(VERSION_H)
	@$(LOG) "LD" "$(OUTPUT)"
	@$(LD) $(LDFLAGS) $(OBJS) -o $@

$(BUILD)/%.o: %.c $(CONFIG_H) $(VERSION_H)
	@mkdir -p $(dir $@) $(DEPSDIR)
	@$(LOG) "CC" "$<"
	@$(CC) $(CFLAGS) $(DEPFLAGS) -c $< -o $@

$(BUILD)/%.o: %.asm
	@mkdir -p $(dir $@) $(DEPSDIR)
	@$(LOG) "ASM" "$<"
	@$(ASM) $(ASMFLAGS) $(DEPFLAGS_ASM) $< -o $@

$(BUILD)/%.o: %.s
	@mkdir -p $(dir $@) $(DEPSDIR)
	@$(LOG) "GASM" "$<"
	@$(GASM) $(GASMFLAGS) $(DEPFLAGS_GASM) -c $< -o $@

$(BUILD)/%.host.o: %.c $(CONFIG_H)
	@mkdir -p $(dir $@) $(DEPSDIR)
	@$(LOG) "HOSTCC" "$<"
	@$(HOSTCC) $(HOSTFLAGS) $(HOSTDEPFLAGS) -c $< -o $@

# hosts
define get_prog_objs
$(filter $(dir $(1))%.host.o,$(HOSTOBJS))
endef

define hostprogs_rule
$(1): $(call get_prog_objs,$(1))
	@$(LOG) "HOSTCC" "$$@"
	@$(HOSTLD) $$^ -o $$@

$(notdir $(1)): $(1)
	@$$<
endef

$(foreach prog,$(HOSTPROGS),$(eval $(call hostprogs_rule,$(prog))))
