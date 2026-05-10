VERSION = 0
PATCHLEVEL = 0
SUBLEVEL = 1
EXTRAVERSION = -rc1
NAME = Program

PROGRAMVERSION = $(VERSION)$(if $(PATCHLEVEL),.$(PATCHLEVEL)$(if $(SUBLEVEL),.$(SUBLEVEL)))$(EXTRAVERSION) VERSIONSTR = $(PROGRAMVERSION) ($(NAME))

HOSTCC   := gcc
HOSTCFLAGS := -Wall -Wextra
HOSTLD   := $(HOSTCC)

CC       := gcc
CFLAGS   := -Wall -Wextra -Iinclude 
LDFLAGS  := 
LD       := $(CC)

-include local.mk

DEPFLAGS = -MMD -MP -MF $(@:.o=.d)

BUILD    := build
OUTPUT   := $(BUILD)/program

OBJS      :=
HOSTOBJS :=
HOSTPROGS :=
DEPS      :=

define config_val
$(shell grep -E '^$(1)=' $(CURDIR)/.config 2>/dev/null | head -1 | sed 's/[^=]*=//' | tr -d '"')
endef

define config_enabled
$(if $(filter y,$(call config_val,$(1))),1,)
endef

define parse_zbuild
$(eval __current_dir := $(dir $(1)))

$(eval _objs := $(shell sed -n 's/^obj-y[[:space:]]*+= *//p' $(1) 2>/dev/null))

$(if $(_objs),\
  $(foreach item,$(_objs),\
    $(if $(filter %/,$(item)),\
      $(call parse_zbuild,$(__current_dir)$(item)Makefile),\
      $(eval OBJS += $(BUILD)/$(__current_dir)$(item))\
    )\
  )\
)

$(eval _config_objs := $(shell sed -n '/^obj-\$$(CONFIG_/ s/^obj-\$$(CONFIG_\([^)]*\))[[:space:]]*+= *//p' $(1) 2>/dev/null))
$(if $(_config_objs),\
  $(foreach item,$(_config_objs),\
    $(eval _var_name := $(shell echo $(item) | sed 's/\.o$$//' | tr 'a-z' 'A-Z'))\
    $(if $(filter y, $(CONFIG_$(_var_name))),\
      $(eval OBJS += $(BUILD)/$(__current_dir)$(item))\
    )\
  )\
)

$(foreach item,$(shell sed -n 's/^hostobj-y[[:space:]]*+= *//p' $(1) 2>/dev/null),\
  $(if $(filter %/,$(item)),\
  	$(call parse_zbuild,$(__current_dir)$(item)Makefile),\
		$(eval HOSTOBJS += $(BUILD)/$(__current_dir)$(item:.o=.host.o))\
  )\
)

$(foreach item,$(shell sed -n 's/^hostprog-y[[:space:]]*+= *//p' $(1) 2>/dev/null),\
  $(if $(filter %/,$(item)),\
    $(call parse_zbuild,$(__current_dir)$(item)Makefile),\
    $(eval HOSTPROGS += $(BUILD)/$(__current_dir)$(item))\
  )\
)

$(eval __current_dir := $(__saved_dir))
endef

-include .config
$(call parse_zbuild,Zbuild)

define get_prog_objs =
$(filter $(dir $(1))%.o,$(HOSTOBJS))
endef

define hostprogs_rule =
$(1): $(call get_prog_objs,$(1))
	@echo "  HOSTLD  $$@"
	@mkdir -p $$(dir $$@)
	@$(HOSTLD) $$^ -o $$@

$(notdir $(1)): $(1)
	@echo "  RUN    $$<"
	@$$<
endef

$(foreach prog,$(HOSTPROGS),$(eval $(call hostprogs_rule,$(prog))))

MAKEFLAGS += --no-print-directory

DEPS += $(OBJS:.o=.d)
DEPS += $(HOSTOBJS:.o=.d)

all: $(OUTPUT)
	@:

defconfig: .config
	@sh scripts/zconfig.sh --def

.config: Zconfig scripts/zconfig.sh
	@sh scripts/zconfig.sh --def
	@touch .config

include/config.h: .config scripts/zconfig.sh
	@mkdir -p include
	@sh scripts/zconfig.sh --header


$(OUTPUT): $(OBJS)
	@echo "  LD    $(OUTPUT)"
	@mkdir -p $(BUILD)
	@$(CC) $(LDFLAGS) $(OBJS) -o $(OUTPUT)

$(BUILD)/%.o: %.c include/config.h
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
	@rm -rf $(BUILD) include/config.h
	@echo "  CLN   .config"
	@rm -rf .config
	@echo "  CLN   include/config.h"
	@rm -rf include/config.h

help:
	@echo "Targets:"
	@echo "  all        - build project"
	@echo "  clean      - remove build/"
	@echo "  run        - run executable"
	@echo "  mconfig    - run menu config"
	@echo "  defconfig  - generate .config"
	@echo "  help       - show help"

.DEFAULT_GOAL := all

.PHONY: all clean run help defconfig mconfig header

-include $(DEPS)
