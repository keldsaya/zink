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

CC     := gcc
LD     := $(CC)
CFLAGS := -Wall -Wextra -Iinclude
LDFLAGS :=

-include local.mk

# paths
BUILD     := build
DEPSDIR   := $(BUILD)/deps
OUTPUT    := $(BUILD)/program
OBJS_MK   := $(BUILD)/generated/objs.mk
CONFIG_H  := include/config.h
VERSION_H := include/version.h

DEPFLAGS     = -MMD -MP -MF $(DEPSDIR)/$(subst /,_,$*).d
HOSTDEPFLAGS = -MMD -MP -MF $(DEPSDIR)/$(subst /,_,$*).host.d

SHELL     := /bin/sh
MAKEFLAGS += --no-print-directory

.DEFAULT_GOAL := all


ifeq ($(filter clean mrproper help defconfig oldconfig savedefconfig,$(MAKECMDGOALS)),)

.config: ./Zconfig scripts/zconfig/entry.sh
	@echo "  GEN   .config"
	@sh scripts/zconfig/entry.sh --defconfig

$(OBJS_MK): .config scripts/zbuild/parse.sh
	@mkdir -p $(dir $(OBJS_MK))
	@sh scripts/zbuild/parse.sh .config

-include $(OBJS_MK)

DEPS := $(addprefix $(DEPSDIR)/,$(subst /,_,$(OBJS:.o=.d))) \
        $(addprefix $(DEPSDIR)/,$(subst /,_,$(HOSTOBJS:.host.o=.host.d)))
-include $(DEPS)

endif

# targets
all: $(CONFIG_H) $(VERSION_H) $(OUTPUT)

run: all
	@echo "  RUN   $(OUTPUT)"
	@$(OUTPUT)

clean:
	@echo "  CLN   build/"
	@rm -rf $(BUILD)
	@echo "  CLN   $(VERSION_H)"
	@rm -f $(VERSION_H)
	@echo "  CLN   $(CONFIG_H)"
	@rm -f $(CONFIG_H)

mrproper: clean
	@echo "  CLN   .config"
	@rm -f .config

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
	@sh scripts/zconfig/entry.sh --header

$(VERSION_H): scripts/version.sh
	@sh scripts/version.sh $(VERSION) $(PATCHLEVEL) $(SUBLEVEL) $(EXTRAVERSION) "$(NAME)" $@

%config: scripts/zconfig/entry.sh
	@case "$@" in \
		.config|Zconfig|mconfig) ;; \
		*/*|*.*) ;; \
		*) sh scripts/zconfig/entry.sh --$@ ;; \
	esac

# compilation
$(OUTPUT): $(OBJS) $(CONFIG_H) $(VERSION_H)
	@echo "  LD    $(OUTPUT)"
	@$(LD) $(LDFLAGS) $(OBJS) -o $@

$(BUILD)/%.o: %.c $(CONFIG_H) $(VERSION_H)
	@mkdir -p $(dir $@) $(DEPSDIR)
	@echo "  CC    $<"
	@$(CC) $(CFLAGS) $(DEPFLAGS) -c $< -o $@

$(BUILD)/%.host.o: %.c $(CONFIG_H)
	@mkdir -p $(dir $@) $(DEPSDIR)
	@echo "  HOSTCC  $<"
	@$(HOSTCC) $(HOSTFLAGS) $(HOSTDEPFLAGS) -c $< -o $@

# hosts
define get_prog_objs
$(filter $(dir $(1))%.host.o,$(HOSTOBJS))
endef

define hostprogs_rule
$(1): $(call get_prog_objs,$(1))
	@echo "  HOSTLD  $$@"
	@$(HOSTLD) $$^ -o $$@

$(notdir $(1)): $(1)
	@$$<
endef

$(foreach prog,$(HOSTPROGS),$(eval $(call hostprogs_rule,$(prog))))
