CC       := gcc
HOSTCC   := gcc

CFLAGS   := -Wall -Wextra -Iinclude
HOSTCFLAGS := -Wall -Wextra

DEPFLAGS = -MMD -MP -MF $(@:.o=.d)

LD       := $(CC)
HOSTLD   := $(HOSTCC)

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
$(eval __saved_dir := $(__dir))
$(eval __dir := $(__current_dir))

$(eval _objs := $(shell sed -n 's/^obj-y[[:space:]]*+= *//p' $(1) 2>/dev/null))

$(if $(_objs),\
  $(foreach item,$(_objs),\
    $(if $(filter %/,$(item)),\
      $(call parse_zbuild,$(__dir)$(item)Makefile),\
      $(eval OBJS += $(BUILD)/$(__dir)$(item))\
    )\
  )\
)

$(eval _config_objs := $(shell sed -n '/^obj-\$$(CONFIG_/ s/^obj-\$$(CONFIG_\([^)]*\))[[:space:]]*+= *//p' $(1) 2>/dev/null))
$(if $(_config_objs),\
  $(foreach item,$(_config_objs),\
    $(eval _var_name := $(shell echo $(item) | sed 's/\.o$$//' | tr 'a-z' 'A-Z'))\
    $(if $(filter y, $(CONFIG_$(_var_name))),\
      $(eval OBJS += $(BUILD)/$(__dir)$(item))\
    )\
  )\
)

$(foreach item,$(shell sed -n 's/^hostobj-y[[:space:]]*+= *//p' $(1) 2>/dev/null),\
  $(if $(filter %/,$(item)),\
  	$(call parse_zbuild,$(__dir)$(item)Makefile),\
  	$(eval HOSTOBJS += $(BUILD)/$(__dir)$(item))\
  )\
)

$(foreach item,$(shell sed -n 's/^hostprogs-y[[:space:]]*+= *//p' $(1) 2>/dev/null),\
  $(if $(filter %/,$(item)),\
    $(call parse_zbuild,$(__dir)$(item)Makefile),\
    $(eval HOSTPROGS += $(BUILD)/$(__dir)$(item))\
  )\
)

$(eval __dir := $(__saved_dir))
endef

-include .config
$(call parse_zbuild,Zbuild)

MAKEFLAGS += --no-print-directory

DEPS += $(OBJS:.o=.d)
DEPS += $(HOSTOBJS:.o=.d)

all: $(OUTPUT)
	@:

.config: Zconfig scripts/zconfig.sh
	@$(MAKE) defconfig

defconfig:
	@sh scripts/zconfig.sh --def

header: .config scripts/zconfig.sh
	@mkdir -p include
	@sh scripts/zconfig.sh --header

include/config.h: .config scripts/zconfig.sh
	@mkdir -p include
	@sh scripts/zconfig.sh --header


$(OUTPUT): $(OBJS)
	@echo "  LD    $(OUTPUT)"
	@mkdir -p $(BUILD)
	@$(CC) $(OBJS) -o $(OUTPUT)

$(BUILD)/%.o: %.c include/config.h
	@echo "  CC    $<"
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) $(DEPFLAGS) -c $< -o $@

$(BUILD)/tools/mconfig/mconfig: $(HOSTOBJS)
	@echo "  HOSTLD $@"
	@mkdir -p $(dir $@)
	@$(HOSTLD) $^ -o $@

$(BUILD)/tools/mconfig/%.o: tools/mconfig/%.c
	@echo "  HOSTCC $<"
	@mkdir -p $(dir $@)
	@$(HOSTCC) $(HOSTCFLAGS) $(DEPFLAGS) -c $< -o $@

run: all
	@echo "  RUN   $(OUTPUT)"
	@$(OUTPUT)

mconfig: $(BUILD)/tools/mconfig/mconfig
	@echo "  RUN   $<"
	@$(BUILD)/tools/mconfig/mconfig

clean:
	@echo "  CLN   build/"
	@rm -rf $(BUILD) include/config.h

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
