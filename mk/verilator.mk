targets += sim vl vl-test

vtop_dir = $(obj)/vl
vtop_exe = $(vtop_dir)/Vtop

vl_main = $(call per_target,vl_main)
vl_main_sv = $(call per_target,vl_main_sv)

vl_run_env = $(core_info/$(rule_top)/vl_run_env)
vl_run_args = $(core_info/$(rule_top)/vl_run_args)
vl_run_dump = $(call core_objs,$(rule_top),vl_run_dump)
vl_run_outputs = $(call core_objs,$(rule_top),vl_run_outputs)
vl_run_cmdline = $(vl_run_env) $(vl_run_exe_default_rel) $(vl_run_args)

vl_run_exe_abs = $(call core_objs,$(rule_top),vl_run_exe)
vl_run_exe_rel = $(core_info/$(rule_top)/vl_run_exe)
vl_run_exe_default_abs = $(if $(vl_run_exe_abs),$(vl_run_exe_abs),$(call require_core_objs,$(rule_top),vl_exe_alias))
vl_run_exe_default_rel = ./$(if $(vl_run_exe_rel),$(vl_run_exe_rel),$(call require_core_var,$(rule_top),vl_exe_alias))

vl_flags = $(call per_target,vl_flags)
vl_cflags = $(call per_target,vl_cflags)
vl_ldflags = $(call per_target,vl_ldflags)

vl_disabled_warnings := UNUSEDSIGNAL UNUSEDPARAM PINCONNECTEMPTY

target/sim/setup :=

define target/vl/setup
  $(setup_verilator_target)

  $$(call target_var,vl_main) := $$(strip $$(call require_core_objs,$$(rule_top),vl_main))
  $$(call target_var,vl_main_sv) := $$(filter %.sv %.v,$$(vl_main))
endef

target/sim/add_default_rule := test

define target/sim/rules
  $(verilator_run_target_rules)
endef

define target/vl/rules
  $(verilator_build_target_rules)
endef

target/vl-test/setup = $(target/vl/setup)
target/vl-test/rules = $(target/vl/rules)
target/vl-test/add_default_rule = test

define setup_verilator_target
  $(call target_var,vl_flags) = $(common_vl_flags)
  $(call target_var,vl_cflags) = $(common_vl_cflags)
  $(call target_var,vl_ldflags) = $(common_vl_ldflags)
endef

$(eval $(call defer,common_vl_flags,$$(set_verilator_common)))
$(eval $(call defer,common_vl_cflags,$$(set_verilator_common)))
$(eval $(call defer,common_vl_ldflags,$$(set_verilator_common)))

define set_verilator_common
  x_mode := $$(if $$(enable_rand),unique,fast)

  static_flags := \
    --x-assign $$(x_mode) --x-initial $$(x_mode) \
    $$(if $$(enable_threads),--threads $$(call shell_checked,nproc)) \
    $$(if $$(enable_trace),--trace $$(if $$(enable_fst),--trace-fst) --trace-structs) \
    $$(if $$(enable_cov),--coverage) \
    $$(if $$(enable_opt),-O3) \
    $$(if $$(enable_prof),--prof-cfuncs) \
    --cc --exe --prefix Vtop --MMD --MP --timescale 1ns/1ns

  common_vl_flags := $$(static_flags) $$(core_info/$$(rule_top)/vl_flags)

  common_vl_cflags := \
    $$(if $$(enable_opt),-march=native -O3) \
    $$(if $$(enable_lto),-flto)

  common_vl_ldflags := \
    $$(if $$(enable_lto),-flto)
endef

define verilator_build_target_rules
  vtop_mk_file := $$(vtop_dir)/Vtop.mk
  vtop_mk_stamp := $$(vtop_dir)/stamp
  vtop_dep_file := $$(vtop_dir)/Vtop__ver.d

  vtop_src_deps := \
    $$(call core_objs,$$(rule_top),vl_files) \
    $$(vl_main)

  -include $$(vtop_dep_file)
  $$(vtop_dep_file):

  $$(vtop_exe): export VPATH := $$(src)
  $$(vtop_exe): $$(vtop_mk_stamp) $$(vtop_src_deps)
	$$(call run_submake,BUILD) $$(if $$(V),,-s) -C $$(vtop_dir) -f Vtop.mk
	@touch -c $$@

  $$(vtop_mk_file):
	@rm -f $$@

  $$(vtop_mk_stamp): $$(rule_inputs) $$(vtop_mk_file) $$(call core_objs,$$(rule_top),rtl_files)
	$$(eval $$(final_vflags))
	$$(call run_no_err,VERILATE) $$(VERILATOR) $$(vl_flags) $$(verilator_src_args)
	@touch $$@

  $$(eval $$(verilator_run_target_rules))
endef

define verilator_run_target_rules
  .PHONY: $$(if $(seed),,$$(obj)/stdout.$$(seed_name).txt)

  $$(obj)/stdout.$$(seed_name).txt $$(vl_run_outputs) &: $$(rule_inputs) $$(vl_run_exe_default_abs) | $$(obj)
	$$(call run,SIM) cd $$(obj) && \
		{ $$(vl_run_cmdline) \
		$$(if $$(seed),+verilator+seed+$$(seed)); \
		echo $$$$? >status.$$(seed_name); } \
		| tee .tmp.stdout.$$(seed_name).txt && \
		status=`cat status.$$(seed_name)` && \
		if [ $$$$status -eq 0 ]; then \
			echo "Simulation $$(build_id) SUCCESS" >&2; \
		else \
			echo "Simulation $$(build_id) FAILURE (status $$$$status):" $$(vl_run_cmdline) >&2; \
		fi
	@cp -T -- $$(obj)/.tmp.stdout.$$(seed_name).txt $$(obj)/stdout.$$(seed_name).txt && rm -f -- $$(obj)/.tmp.stdout.$$(seed_name).txt

  ifneq (,$$(vl_run_dump))
    define core_info/$$(rule_top)/post_build
		$$(if $$(enable_gtkwave),$$(call run_no_err,GTKWAVE) $$(GTKWAVE) $$(vl_run_dump).$$(if $$(enable_fst),fst,vcd))
    endef
  endif
endef

define final_vflags
  $(call find_with_pkgconfig, \
    $(core_info/$(rule_top)/vl_pkgconfig), \
    $(call target_var,vl_cflags), \
    $(call target_var,vl_ldflags))

  $$(call target_var,vl_flags) := \
    $$(if $$(vl_main_sv),--main --timing) \
    $$(vl_flags) \
    -Wall -Wpedantic $$(addprefix -Wno-,$$(vl_disabled_warnings)) \
    --Mdir $$(vtop_dir)

  $$(call target_var,vl_cflags) := $$(strip $$(vl_cflags))
  $$(call target_var,vl_ldflags) := $$(strip $$(vl_ldflags))

  # Verilator's wrapper script can't handle `-CFLAGS ''` correctly
  ifneq (,$$(vl_cflags))
    $$(call target_var,vl_flags) += -CFLAGS '$$(vl_cflags)'
  endif

  ifneq (,$$(vl_ldflags))
    $$(call target_var,vl_flags) += -LDFLAGS '$$(vl_ldflags)'
  endif
endef

verilator_src_args = \
  $(strip \
    --top $(call require_core_var,$(rule_top),rtl_top) \
    $(call core_objs,$(rule_top),rtl_files) \
    $(call core_objs,$(rule_top),vl_files) \
    $(if $(vl_main),$(vl_main),$(error $$(vl_main) not defined by target '$(rule_target)')))
