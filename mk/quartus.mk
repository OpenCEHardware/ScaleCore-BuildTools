# Based on github:alexforencich/verilog-ethernet:example/DE2-115/fpga/common/quartus.mk

targets += quartus

quartus_qsf = $(obj)/$(quartus_top).qsf
quartus_qpf = $(obj)/$(quartus_top).qpf
quartus_run = cd $(obj) && $(QUARTUS)

quartus_top = $(call require_core_var,$(rule_top),rtl_top)
quartus_device = $(call require_core_var,$(rule_top),altera_device)
quartus_family = $(call require_core_var,$(rule_top),altera_family)


quartus_rtl_abs  = $(call require_core_objs,$(rule_top),rtl_files)
quartus_rtl_rel  = $(call require_core_var,$(rule_top),rtl_files)
quartus_sdc_abs  = $(call core_objs,$(rule_top),sdc_files)
quartus_sdc_rel  = $(core_info/$(rule_top)/sdc_files)
quartus_tcl_abs  = $(call core_objs,$(rule_top),qsf_files)
quartus_tcl_rel  = $(core_info/$(rule_top)/qsf_files)
quartus_qip_abs  = $(call core_objs,$(rule_top),qip_files)
quartus_qip_rel  = $(core_info/$(rule_top)/qip_files)
quartus_qsys_abs = $(call core_objs,$(rule_top),qsys_platforms)
quartus_qsys_rel = $(core_info/$(rule_top)/qsys_platforms)

quartus_src_files = $(quartus_rtl_abs) $(quartus_sdc_abs) $(quartus_qip_abs) $(quartus_qsys_abs) $(quartus_tcl_abs)

quartus_plat_qip_abs = $(addprefix $(obj)/,$(quartus_plat_qip_rel))
quartus_plat_qip_rel = $(foreach plat,$(quartus_qsys_rel),$(call quartus_plat_path,$(plat)))
quartus_plat_path    = qsys/$(basename $(notdir $(1)))/synthesis/$(basename $(notdir $(1))).qip

define target/quartus/rules
  define core_info/$$(rule_top)/post_build
	$$(if $$(enable_gui),$$(call run,GUI) $$(quartus_run) $$(quartus_top).qpf)
  endef

  $$(obj)/asm.stamp $$(obj)/$$(quartus_top).sof &: $$(obj)/sta.stamp
	$$(call run,ASM) $$(quartus_run)_asm $$(quartus_top)
	@touch -- $$(obj)/asm.stamp

  $$(obj)/sta.stamp: $$(obj)/fit.stamp
	$$(call run,STA) $$(quartus_run)_sta $$(quartus_top)
	@touch -- $$@

  $$(obj)/fit.stamp: $$(obj)/map.stamp
	$$(call run,FIT) $$(quartus_run)_fit --part=$$(quartus_device) $$(quartus_top)
	@touch -- $$@

  $$(obj)/map.stamp: $$(quartus_qpf)
	$$(call run,MAP) $$(quartus_run)_map --family="$(quartus_family)" $$(quartus_top)
	@touch -- $$@

  $$(quartus_qsf) $$(quartus_qpf) &: $$(rule_inputs) $$(quartus_src_files) $$(quartus_plat_qip_abs)
	$$(call run,QSF) \
		rm -f $$(quartus_qsf) $$(quartus_qpf) && \
		cd $$(obj) && \
		echo 'PROJECT_REVISION = "$$(quartus_top)"' >.tmp.$$(quartus_top).qpf && \
		exec >.tmp.$$(quartus_top).qsf && \
		echo 'set_global_assignment -name FAMILY "$$(quartus_family)"' && \
		echo 'set_global_assignment -name DEVICE $$(quartus_device)' && \
		echo 'set_global_assignment -name TOP_LEVEL_ENTITY $$(quartus_top)' && \
		printf "\n\n# Source files\n" && \
		assignment() { echo set_global_assignment -name $$$$1 $$$$2; } && \
		assignment_list() { \
			title="$$$$1"; \
			name="$$$$2"; \
			shift 2; \
			printf "\n# $$$$title\n" && \
			for x in $$$$@; do assignment "$$$${name}" "$$$$x"; done \
		} && \
		for x in $$(quartus_rtl_rel); do \
			case $$$${x##*.} in \
				[Vv])         name=VERILOG_FILE ;; \
				[Ss][Vv])     name=SYSTEMVERILOG_FILE ;; \
				[Vv][Hh][Dd]) name=VHDL_FILE ;; \
				*)            name=SOURCE_FILE ;; \
			esac; \
			assignment "$$$$name" "$$$$x"; \
		done && \
		assignment_list "Constraint files" SDC_FILE $$(quartus_sdc_rel) && \
		assignment_list "IPs" QIP_FILE $$(quartus_qip_rel) && \
		assignment_list "Platform IPs" QIP_FILE $$(quartus_plat_qip_rel) && \
		assignment_list "Platforms" QSYS_FILE $$(notdir $$(quartus_qsys_rel)) && \
		for x in $$(quartus_tcl_rel); do printf "\n#\n# TCL file %s\n#\n" "$$$$x"; cat "$$$$x"; done
	@mv -T -- $$(obj)/.tmp.$$(quartus_top).qpf $$(obj)/$$(quartus_top).qpf
	@mv -T -- $$(obj)/.tmp.$$(quartus_top).qsf $$(obj)/$$(quartus_top).qsf

  quartus_hwip_abs :=

  $$(foreach qsys_dep,$$(call core_objs,$$(rule_top),qsys_deps), \
    $$(eval $$(call quartus_qsys_hwip_rules,$$(qsys_dep))))

  $$(foreach plat,$$(quartus_qsys_abs), \
    $$(eval $$(call quartus_qsys_platform_rules,$$(plat))))

  quartus_hwip_abs :=
endef

define quartus_qsys_platform_rules
  qip_file := $$(obj)/$$(call quartus_plat_path,$(1))
  qsys_src_file := $(1)
  qsys_dst_file := $$(notdir $$(qsys_src_file))

  $$(obj)/$$(qsys_dst_file): $$(qsys_src_file)
	@cp -T -- $$< $$@

  $$(qip_file): qsys_dst_file := $$(qsys_dst_file)
  $$(qip_file): $$(obj)/$$(qsys_dst_file) $$(quartus_hwip_abs)
	$$(call run,QSYS,$(1)) cd $$(obj) && $$(QSYS_GENERATE) \
		-syn --part=$$(quartus_device) --output-directory=qsys/$$(basename $$(qsys_dst_file)) $$(qsys_dst_file)
endef

define quartus_qsys_hwip_rules
  tcl_src_file := $(1)
  tcl_basename := $$(notdir $$(tcl_src_file))
  tcl_dst_file := $$(obj)/$$(tcl_basename)
  tcl_rtl_deps := $$(call core_objs,$$(rule_top),rtl_files/$$(tcl_basename))

  quartus_hwip_abs += $$(tcl_dst_file)

  $$(tcl_dst_file): $$(tcl_src_file) $$(tcl_rtl_deps)
	$$(call run,HWTCL,$(1)) \
		exec >>$$(dir $$@)/.tmp.$$(notdir $$@) && \
		cat $$< && \
		echo && \
		echo "# Source filelist" && \
		add_src_file() { \
			src_path="$$$$1"; \
			ext="$$$$2"; \
			src_basename="$$$$(basename "$$$$src_path")"; \
			top=; \
			if [ "$$$${src_basename%.*}" = "$$(core_info/$$(rule_top)/rtl_top/$$(tcl_basename))" ]; then \
				top=" TOP_LEVEL_FILE"; \
			fi; \
			echo add_fileset_file "$$$$(basename "$$$$src_path")" "$$$$ext" PATH "$$$$src_path$$$$top"; \
		} && \
		for x in $$(core_info/$$(rule_top)/rtl_files/$$(tcl_basename)); do \
			case $$$${x##*.} in \
				[Ss][Vv]) ext=SYSTEM_VERILOG ;; \
				*)        echo "Unknown file extension for qsys IP: $$$$x" >&2; exit 1 ;; \
			esac && \
			add_src_file "$$$$x" "$$$$ext"; \
		done
	@mv -T -- $$(dir $$@)/.tmp.$$(notdir $$@) $$@
endef
