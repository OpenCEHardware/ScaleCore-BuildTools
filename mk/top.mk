.PHONY: all .force

all:
.force:

empty :=
space := $(empty) $(empty)
comma := ,

# Both empty lines are required
define newline


endef

newline := $(newline)

defer = $(1) = $$(eval $(2))$$($(1))

# Path to the 'mk' directory
MK ?= $(abspath ./mk)

# Random seed. Usage example: make <target> seed=123
seed_name := $(if $(seed),$(seed),no-seed)

all_flags := \
  cov        \
  fst        \
  gtkwave    \
  gui        \
  lto        \
  opt        \
  prof       \
  rand       \
  synthesis  \
  threads    \
  trace

override enable_opt       := 1
override enable_synthesis := 1

$(foreach flag,$(subst $(comma),$(space),$(enable)), \
  $(if $(filter $(flag),$(all_flags)),,$(error unknown flag '$(flag)')) \
  $(eval override enable_$(flag) := 1))

ifneq (,$(enable_lto))
  override enable_opt := 1
endif

ifneq (,$(enable_gtkwave))
  override enable_trace := 1
endif

ifneq (,$(enable_trace))
  override enable_fst := 1
endif

$(foreach flag,$(subst $(comma),$(space),$(disable)), \
  $(if $(filter $(flag),$(all_flags)),,$(error unknown flag '$(flag)')) \
  $(eval override enable_$(flag) :=))

ifneq (,$(seed))
  $(if $(enable_rand),,$(error cannot set seed=$(seed) without enable=rand))
endif

build_id_tag := $(subst $(space),-,$(sort $(strip $(foreach flag,$(all_flags),$(if $(enable_$(flag)),$(flag))))))
ifeq (,$(build_id_tag))
  build_id_tag := none
endif

enabled_flags  := $(subst $(space),$(comma),$(sort $(strip $(foreach flag,$(all_flags),$(if $(enable_$(flag)),$(flag))))))
disabled_flags := $(subst $(space),$(comma),$(sort $(strip $(foreach flag,$(all_flags),$(if $(enable_$(flag)),,$(flag))))))

# Expliclty include every *.mk submodule
include $(MK)/autococo.mk
include $(MK)/bin2rel.mk
include $(MK)/build.mk
include $(MK)/cocotb.mk
include $(MK)/cov.mk
include $(MK)/cross.mk
include $(MK)/lint.mk
include $(MK)/meson.mk
include $(MK)/peakrdl.mk
include $(MK)/quartus.mk
include $(MK)/tools.mk
include $(MK)/verilator.mk

$(eval $(find_tools_lazy))

.PHONY: clean
clean:
	rm -frv -- $(O)

db_mk_dir := $(O)/mk/$(build_id_tag)
db_mk := $(db_mk_dir)/db.mk

include $(db_mk)

$(db_mk): $(build_makefiles)
	$(PYTHON3) -m mk \
		--source="$(src)" \
		--output="$(db_mk_dir)" \
		--enable="$(enabled_flags)" \
		--disable="$(disabled_flags)"

ifneq (,$(last_src))
  ifneq ($(src),$(last_src))
	$(error $(O): attempt to rebuild after switching the absolute path of $$(src) from '$(last_src)' to '$(src)'. This is not supported. Please run 'make clean')
  endif
endif

define target_entry
  .PHONY: $$(rule_top_path) $$(rule_top_path)/

  $$(rule_top_path)/: $$(rule_top_path)

  $$(rule_top_path): $$(call require_core_objs,$$(rule_top),outputs) | $$(obj)
	@echo >&2
	@echo ================================================================================= >&2
	@echo "Build output directory for package $$(rule_top) ($$(rule_target)):" >&2
	@echo "$$(realpath $$(obj))" >&2
	@echo ================================================================================= >&2
	$$(core_info/$$(rule_top)/post_build)

  $$(foreach output,$$(rule_outputs) $$(rule_top_path),$$(eval $$(call target_entrypoint,$$(output))))
endef

$(foreach core,$(all_cores), \
  $(eval rule_top := $(core)) \
  $(eval $(target_entry)))

$(foreach core,$(all_cores), \
  $(eval rule_top := $(core)) \
  $(if $(filter $(rule_target),$(targets)),,$(error in '$(rule_top)': bad target '$(rule_target)')) \
  $(eval $(target/$(rule_target)/setup)))

$(foreach core,$(all_cores), \
  $(eval rule_top := $(core)) \
  $(eval $(target/$(rule_target)/rules)))

rule_top = $(error invalid reference to $$(rule_top) after rule setup)

all: $(foreach core,$(all_cores),$(core_info/$(core)/path))

$(foreach target,$(targets), \
  $(foreach default,$(target/$(target)/add_default_rule), \
    $(eval .PHONY: $(default)) \
    $(eval $(default): $(foreach core,$(all_cores),$(if $(filter $(target),$(core_info/$(core)/target)),$(core_info/$(core)/path))))))
