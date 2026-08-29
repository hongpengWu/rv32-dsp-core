set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]
set project_dir [file join $repo_dir build vivado]
set core_dir [file join $repo_dir rtl core]

create_project -force rv32_dsp_core $project_dir -part xc7z020clg400-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

add_files -norecurse [glob -directory $core_dir *.sv]
set_property include_dirs [list $core_dir] [get_filesets sources_1]
set_property top myCPU [get_filesets sources_1]

add_files -fileset sim_1 -norecurse [file join $repo_dir sim tb_core_smoke.sv]
set_property include_dirs [list $core_dir] [get_filesets sim_1]
set_property top tb_core_smoke [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Created PYNQ-Z2 project at $project_dir"
close_project

