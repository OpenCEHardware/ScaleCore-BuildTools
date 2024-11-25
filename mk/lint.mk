targets += lint

target/lint/add_default_rule := lint
target/lint/no_build_dir_print := 1

lint_rtl = $(call core_objs,$(rule_top),rtl_files)

define target/lint/rules
  $$(obj)/lint.stamp: $$(rule_inputs) $(lint_rtl) | $$(obj)
	$$(call run_no_err,LINT) $$(VERIBLE_LINT) $$(if $$(lint_rtl),$$$$(realpath --relative-to=. -- $$(lint_rtl)))
	@touch -- $$@

  ifeq (,$$(lint_rtl))
    $$(obj):
		@mkdir -p $$@
  endif
endef
