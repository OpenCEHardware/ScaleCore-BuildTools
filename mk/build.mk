O   := build
src := $(abspath .)

obj           = $(core_info/$(rule_top)/obj)
build_id      = $(core_info/$(rule_top)/build_id)
rule_target   = $(core_info/$(rule_top)/target)
rule_top_path = $(core_info/$(rule_top)/path)
rule_inputs   = $(db_mk) $(call core_objs,$(rule_top),obj_deps)
rule_outputs  = $(call require_core_objs,$(rule_top),outputs)

build_vars = $(error call to deprecated build_vars)
add_build_var = $(error call to deprecated add_build_var)

build_makefiles := $(wildcard $(MK)/*.mk $(MK)/*.py $(MK)/scripts/*)
$(build_makefiles):

build_makefiles += Makefile

define find_command_lazy
  $(2)_cmdline := $$($(2))
  override $(call defer,$(2),$$(call find_command,$(1),$(2)))
  override $(call defer,$(2)_quiet,$$(call find_command_quiet,$(1),$(2)))
endef

define find_command
  override $(2) := $$($(2)_quiet)

  ifeq (,$$($(2)))
    ifneq ($(1),$$($(2)_cmd))
      $$(error $(1) ($$($(2)_cmd)) not found, please install missing software)
    else
      $$(error $(1) not found, please install missing software or set $(2) accordingly)
    endif
  endif
endef

define find_command_quiet
  override $(2)_cmd := $$($(2)_cmdline)
  ifeq (,$$($(2)_cmd))
    override $(2)_cmd := $(1)
  endif

  which_out := $$(shell which $$($(2)_cmd) 2>/dev/null)

  ifneq (0,$$(.SHELLSTATUS))
    which_out :=
  endif

  ifeq (,$$(which_out))
    override $(2)_quiet :=
  else
    override $(2)_quiet := $$($(2)_cmd)
  endif
endef

shell_defer = $(call defer,$(1),$(1) := $$(call shell_checked,$(2)))
shell_checked = $(shell $(1))$(if $(filter-out 0,$(.SHELLSTATUS)),$(error Command failed: $(1)))

define find_with_pkgconfig
  pkgs := $(strip $(1))

  ifneq (,$$(pkgs))
    ifeq (undefined,$$(origin pkgconfig_cflags/$$(pkgs)))
      $$(eval $$(run_pkgconfig))
    endif

    $(2) += $$(pkgconfig_cflags/$$(pkgs))
    $(3) += $$(pkgconfig_libs/$$(pkgs))
  endif
endef

define run_pkgconfig
  pkgconfig_cflags/$$(pkgs) := $$(shell $$(PKG_CONFIG) --cflags $$(pkgs))
  ifeq (0,$$(.SHELLSTATUS))
    pkgconfig_libs/$$(pkgs) := $$(shell $$(PKG_CONFIG) --libs $$(pkgs))
  endif

  ifneq (0,$$(.SHELLSTATUS))
    $$(error pkg-config failed for package list: $$(pkgs))
  endif
endef

core_objs = $(addprefix $(core_info/$(1)/obj)/,$(core_info/$(1)/$(2)))

require_core_objs = $(addprefix $(core_info/$(1)/obj)/,$(call require_core_var,$(1),$(2)))

require_core_var = \
  $(strip \
    $(eval var_val := $$(core_info/$(1)/$(2))) \
    $(if $(var_val),$(var_val),$(error core '$(1)' must define '$(2)')))

core_shell = $(call shell_checked,cd $(here); $(1))

$(V).SILENT:

run = \
  $(call run_common,$(1),$(2),$(3)) \
  $(if $(V),$(newline)$(3),;trap '[ $$? -eq 0 ] && exit 0 || echo "Exited with code $$?: $$BASH_COMMAND" >&2' EXIT;)

run_no_err = $(call run_common,$(1),$(2),$(3))$(newline)$(3)

run_common = \
  $(3)@printf '%s %-12s %-9s %s\n' '$(build_id)' '($(rule_target))' '$(1)' '$(if $(2),$(2),$(rule_top_path))'

run_submake = $(call run_no_err,$(1),$(2),+)$(MAKE)

target_var = $(1)/$(rule_target)/$(rule_top)
per_target = $($(call target_var,$(1)))

rule_top_path = $(core_info/$(rule_top)/path)

define target_entrypoint
  $(1): rule_top := $$(rule_top)
  $(1): rule_target := $$(rule_target)
endef

define setup_submake_rules
  .PHONY: $$(targets)

  other_targets := $$(filter-out $$(target),$$(targets))

  $$(foreach t,$$(targets),$$(eval $$(call top_rule,$$(t))))

  ifeq (,$$(target))
    $$(foreach other,$$(other_targets), \
      $$(foreach core,$$(all_cores), \
        $$(eval $$(call submake_rule,$$(other),$$(core)))))
  else
    $$(foreach core,$$(filter-out $$(top),$$(all_cores)), \
      $$(eval $$(call submake_rule,$$(target),$$(core))))
  endif
endef

define top_rule
  $(1): $$(top_path)/$(1)
endef

define submake_rule
  path := $$(core_info/$(2)/path)/$(1)

  .PHONY: $$(path)

  $$(path):
	+$$(MAKE) --no-print-directory target=$(1) top=$(2) $$@
endef
