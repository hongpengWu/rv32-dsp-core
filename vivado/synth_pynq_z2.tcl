set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]
set project_dir [file join $repo_dir build vivado_pynq_z2]
set report_dir [file join $repo_dir build reports_pynq_z2]
set mem_file [file normalize [file join $repo_dir mem pynq_demo.mem]]

file mkdir $report_dir
open_project [file join $project_dir rv32_dsp_pynq_z2.xpr]
set_property top rv32_pynq_z2_demo [get_filesets sources_1]
update_compile_order -fileset sources_1
synth_design -top rv32_pynq_z2_demo -part xc7z020clg400-1 -generic "IMEM_INIT_FILE=$mem_file"
report_utilization -file [file join $report_dir utilization.rpt]
report_timing_summary -file [file join $report_dir timing_summary.rpt]
write_checkpoint -force [file join $report_dir post_synth.dcp]
puts "PYNQ-Z2 synthesis completed"
close_project
