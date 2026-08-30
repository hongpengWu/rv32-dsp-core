set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]
set project_dir [file join $repo_dir build vivado_pynq_z2_nano]
set output_dir [file join $repo_dir build bitstream_pynq_z2_nano]
set project_file [file join $project_dir rv32_dsp_pynq_z2_nano.xpr]
set mem_file [file normalize [file join $repo_dir build rtthread_nano program.mem]]

if {![file exists $project_file]} {
    error "Nano Vivado project not found; run create_pynq_z2_nano_project.tcl first"
}
if {![file exists $mem_file]} {
    error "RT-Thread Nano image not found at $mem_file; run scripts/build_rtthread_nano.ps1 first"
}

file mkdir $output_dir
open_project $project_file
set_param general.maxThreads 8
set jobs 8
set_property generic [list IMEM_INIT_FILE=$mem_file] [get_filesets sources_1]
set_property top rv32_pynq_z2_nano [get_filesets sources_1]
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs $jobs
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] != "synth_design Complete!"} {
    error "PYNQ-Z2 Nano synthesis did not complete successfully"
}

# Stop the implementation run after routing.  Vivado 2024.2 can mark the
# generated impl run failed while producing its optional parallel power
# report, even though placement and routing are complete.  We perform the
# sign-off reports and bitstream write explicitly below.
launch_runs impl_1 -to_step route_design -jobs $jobs
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] != "route_design Complete!"} {
    error "PYNQ-Z2 Nano implementation/routing did not complete successfully"
}

open_run impl_1
report_utilization -file [file join $output_dir utilization_post_route.rpt]
report_timing_summary -file [file join $output_dir timing_post_route.rpt]
report_drc -file [file join $output_dir drc_post_route.rpt]
write_bitstream -force [file join $output_dir rv32_pynq_z2_nano.bit]
puts "PYNQ-Z2 RT-Thread Nano bitstream generated at $output_dir"
close_project
