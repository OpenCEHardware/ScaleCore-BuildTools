targets += cocotb

cocotb_modules = $(call per_target,cocotb_modules)

cocotb_pythonpath = $(call require_core_var,$(rule_top),cocotb_paths)
cocotb_pythonpath_decl = PYTHONPATH="$(subst $(space),:,$(patsubst %,./%,$(strip $(cocotb_pythonpath))) $$PYTHONPATH)"

target/cocotb/add_default_rule := test

define target/cocotb/setup
  $$(call target_var,cocotb_modules) := $$(call require_core_var,$$(rule_top),cocotb_modules)

  ifneq (,$$(cocotb_share_quiet))
    $(setup_verilator_target)

    $$(call target_var,vl_main) = $$(cocotb_share)/lib/verilator/verilator.cpp
    $$(call target_var,vl_flags) += --vpi --public-flat-rw
    $$(call target_var,vl_ldflags) += \
      -Wl,-rpath,$$(cocotb_libdir),-rpath,$$(dir $$(cocotb_libpython)) -L$$(cocotb_libdir) \
      -lcocotbvpi_verilator -lgpi -lcocotb -lgpilog -lcocotbutils $$(cocotb_libpython)
  endif
endef

define target/cocotb/rules
  $$(patsubst %,$$(obj)/html/%.html,$$(cocotb_modules)) &: $$(rule_inputs) | $$(obj)
	$$(call run,PDOC) cd $$(obj) && $$(cocotb_pythonpath_decl) $$(PDOC3) --html --force -- $$(cocotb_modules)
	@touch -c -- $$(patsubst %,$$(obj)/html/%.html,$$(cocotb_modules))

  ifneq (,$$(cocotb_share_quiet))
    core_info/$$(rule_top)/vl_run_args :=
    core_info/$$(rule_top)/vl_run_dump := dump
    core_info/$$(rule_top)/vl_run_outputs :=

	core_info/$$(rule_top)/vl_run_env := \
      LIBPYTHON_LOC=$$(cocotb_libpython) \
      COCOTB_RESULTS_FILE=.tmp.results.$$(seed_name).xml \
      $$(if $$(seed),RANDOM_SEED=$$(seed)) \
      $$(cocotb_pythonpath_decl) \
      MODULE=$$(subst $$(space),$$(comma),$$(cocotb_modules))

    $$(eval $$(verilator_build_target_rules))

    $$(obj)/results.$$(seed_name).xml: $$(obj)/stdout.$$(seed_name).txt
		@if [ -f $$(obj)/.tmp.results.$$(seed_name).xml ]; then \
			cp -T -- $$(obj)/.tmp.results.$$(seed_name).xml $$@ && rm -f -- $$(obj)/.tmp.results.$$(seed_name).xml; \
			fi
  else
    $$(obj)/results.$$(seed_name).xml:
		@$$(cocotb_share)
		@false
  endif
endef
