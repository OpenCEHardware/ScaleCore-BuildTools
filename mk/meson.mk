targets += meson

ninja_dir_abs = $(obj)/$(ninja_dir_rel)
ninja_dir_rel = ninja/$(rule_top)
meson_src_abs = $(call require_core_objs,$(rule_top),meson_src)
meson_src_rel = $(call require_core_var,$(rule_top),meson_src)
meson_stamp   = $(ninja_dir_abs)/meson.stamp
ninja_stamp   = $(ninja_dir_abs)/ninja.stamp

define target/meson/rules
  $$(rule_outputs): $$(ninja_stamp)

  $$(ninja_stamp): $$(meson_stamp)
	$$(call run_no_err,NINJA) cd $$(obj) && $$(NINJA) -C $$(ninja_dir_rel) install
	@touch $$@

  $$(meson_stamp): | $$(obj)
  $$(meson_stamp): $$(rule_inputs) $$(meson_src_abs)
	$$(call run,MESON) cd $$(obj) && $$(MESON) setup \
		$$(meson_src_rel) $$(ninja_dir_rel) \
		$$(core_info/$(rule_top)/meson_args)
	@touch $$@
endef
