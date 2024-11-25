targets += cross

cc_ar_lib       = $(call core_objs,$(rule_top),ar_lib)
cc_ld_bin       = $(call require_core_objs,$(rule_top),ld_binary)
cc_srcs_abs     = $(call require_core_objs,$(rule_top),cc_files)
cc_srcs_rel     = $(call require_core_var,$(rule_top),cc_files)
cc_objs         = $(call cc_srcs_to_objs,$(cc_srcs_abs))
cc_srcs_to_objs = $(patsubst %.S,%.o,$(patsubst %.s,%.o,$(patsubst %.cpp,%.o,$(patsubst %.c,%.o,$(1)))))

define target/cross/rules
  ifneq (,$$(cc_ar_lib))
    $$(cc_ar_lib): $$(rule_inputs) $$(cc_objs)
		$$(call run,AR) \
			rm -f $$@ && \
			$$(core_info/$$(rule_top)/cross)ar rcs --thin $$@ $$(cc_objs) \
			&& echo -e 'create $$@\naddlib $$@\nsave\nend' | \
			$$(core_info/$$(rule_top)/cross)ar -M
  else
    $$(cc_ld_bin): $$(rule_inputs) $$(cc_objs)
		$$(call run,LD) $$(core_info/$(rule_top)/cross)gcc \
			$$(core_info/$$(rule_top)/cc_flags) $$(core_info/$$(rule_top)/ld_flags) \
			-o $$@ \
			-Wl,--whole-archive $$(cc_objs) -Wl,--no-whole-archive

    $$(cc_ld_bin).bin: $$(cc_ld_bin)
		$$(call run,OBJCOPY) $$(core_info/$$(rule_top)/cross)objcopy -O binary -- $$< $$@

    $$(cc_ld_bin).hex: $$(cc_ld_bin).bin
		$$(call run,BIN2HEX) $$(PYTHON3) $$(MK)/scripts/bin2hex.py -b $$< -o $$(dir $$@)/.tmp.$$(notdir $$@)
		@mv -T -- $$(dir $$@)/.tmp.$$(notdir $$@) $$@
  endif

  $$(foreach src,$$(cc_srcs_rel), \
    $$(eval $$(call cc_unit_rule,$$(rule_top),$$(src),$$(call cc_srcs_to_objs,$$(src)))))
endef

define cc_unit_rule
  ifneq ($(3),$(2))
    $$(obj)/$(3): $$(obj)/$(2) $$(rule_inputs)
		$$(call run,CC,$(2)) $$(core_info/$(1)/cross)gcc $$(core_info/$(1)/cc_flags) $$(if $$(enable_opt),-O3) -MMD -c $$< -o $$@

    -include $$(patsubst %.o,%.d,$$(obj)/$(3))
  endif
endef
