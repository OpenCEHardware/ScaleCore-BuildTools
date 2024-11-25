targets += regblock

regblock_out   = $(obj)/regblock/$(rule_top)
regblock_rdl   = $(call require_core_objs,$(rule_top),regblock_rdl)
regblock_top   = $(call require_core_var,$(rule_top),regblock_top)
regblock_cpuif = $(call require_core_var,$(rule_top),regblock_cpuif)

define target/regblock/rules
  regblock_rtl := $$(addprefix $$(regblock_out)/,$$(regblock_top)_pkg.sv $$(regblock_top).sv)

  $$(regblock_rtl) &: $$(rule_inputs) $$(regblock_rdl)
	$$(call run,REGBLOCK) $$(PEAKRDL) regblock $$(regblock_rdl) \
		-o $$(regblock_out) --cpuif=$$(regblock_cpuif) --rename=$$(regblock_top) \
		$$(core_info/$$(rule_top)/regblock_args)
endef
