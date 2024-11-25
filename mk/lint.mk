targets += lint

target/lint/add_default_rule := lint

define target/lint/rules
  $$(obj)/lint.stamp: $$(rule_inputs) $$(call core_objs,$$(rule_top),rtl_files)
	$$(call run_no_err,LINT) $$(VERIBLE_LINT) $$$$(realpath --relative-to=. -- $$(call core_objs,$$(rule_top),rtl_files))
endef
