set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]
set project_dir [file join $repo_dir build vivado_pynq_z2_sync]
set output_dir [file join $repo_dir build bitstream_pynq_z2_sync]
set project_file [file join $project_dir rv32_dsp_pynq_z2_sync.xpr]
set mem_file [file normalize [file join $repo_dir mem pynq_demo.mem]]

file mkdir $output_dir
open_project $project_file
set_property generic [list IMEM_INIT_FILE=$mem_file] [get_filesets sources_1]
set_property top rv32_pynq_z2_sync_demo [get_filesets sources_1]
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] != "synth_design Complete!"} {
    error "Synchronous PYNQ synthesis did not complete successfully"
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] != "write_bitstream Complete!"} {
    error "Synchronous PYNQ implementation or bitstream generation failed"
}

open_run impl_1
report_utilization -file [file join $output_dir utilization_post_route.rpt]
report_timing_summary -file [file join $output_dir timing_post_route.rpt]
report_drc -file [file join $output_dir drc_post_route.rpt]
write_bitstream -force [file join $output_dir rv32_pynq_z2_sync_demo.bit]
puts "Synchronous PYNQ-Z2 bitstream generated at $output_dir"
close_project
