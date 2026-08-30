set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]
set project_dir [file join $repo_dir build vivado_pynq_z2_nano]
set core_dir [file join $repo_dir rtl core]
set soc_dir [file join $repo_dir rtl soc]
set xdc_file [file join $repo_dir vivado constraints pynq_z2_nano.xdc]

create_project -force rv32_dsp_pynq_z2_nano $project_dir -part xc7z020clg400-1
set_property target_language Verilog [current_project]
add_files -norecurse [glob -directory $core_dir *.sv]
add_files -norecurse [glob -directory $soc_dir *.sv]
add_files -fileset constrs_1 -norecurse $xdc_file
set_property include_dirs [list $core_dir $soc_dir] [get_filesets sources_1]
set_property top rv32_pynq_z2_nano [get_filesets sources_1]
update_compile_order -fileset sources_1
puts "Created PYNQ-Z2 RT-Thread Nano project at $project_dir"
close_project
