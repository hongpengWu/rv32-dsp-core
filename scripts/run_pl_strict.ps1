[CmdletBinding()]
param(
    [string]$VivadoBin = 'E:\Xilinx\Vivado\2024.2\bin'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

$tests = @(
    @{ Name = 'smoke'; Script = 'run_xsim.ps1'; Pass = 'SMOKE PASS:' },
    @{ Name = 'hazard'; Script = 'run_hazard_xsim.ps1'; Pass = 'HAZARD PASS' },
    @{ Name = 'control-hazard'; Script = 'run_control_flow_xsim.ps1'; Pass = 'CONTROL PASS:' },
    @{ Name = 'directed-rv32i'; Script = 'run_directed_xsim.ps1'; Pass = 'DIRECTED PASS:' },
    @{ Name = 'load-store'; Script = 'run_load_store_xsim.ps1'; Pass = 'LOAD/STORE PASS:' },
    @{ Name = 'system-trap'; Script = 'run_system_xsim.ps1'; Pass = 'SYSTEM PASS:' },
    @{ Name = 'sync-memory-model'; Script = 'run_sync_mem_xsim.ps1'; Pass = 'SYNC MEM PASS:' },
    @{ Name = 'sync-core'; Script = 'run_cpu_sync_xsim.ps1'; Pass = 'SYNC CORE PASS:' },
    @{ Name = 'sync-control'; Script = 'run_cpu_sync_control_xsim.ps1'; Pass = 'SYNC CONTROL PASS:' },
    @{ Name = 'sync-misaligned'; Script = 'run_cpu_sync_misaligned_xsim.ps1'; Pass = 'SYNC MISALIGNED PASS:' },
    @{ Name = 'machine-timer'; Script = 'run_machine_timer_xsim.ps1'; Pass = 'TIMER PASS:' },
    @{ Name = 'sync-irq'; Script = 'run_cpu_sync_irq_xsim.ps1'; Pass = 'IRQ PASS:' },
    @{ Name = 'rv32m-multiply'; Script = 'run_mul_xsim.ps1'; Pass = 'MUL PASS:' },
    @{ Name = 'custom-dsp'; Script = 'run_dsp_custom_xsim.ps1'; Pass = 'DSP CUSTOM PASS:' },
    @{ Name = 'nano-soc'; Script = 'run_nano_soc_xsim.ps1'; Pass = 'NANO SOC XSIM PASS' },
    @{ Name = 'pynq-pl-demo'; Script = 'run_pynq_demo_xsim.ps1'; Pass = 'PYNQ DEMO PASS:' },
    @{ Name = 'pynq-sync-demo'; Script = 'run_pynq_sync_demo_xsim.ps1'; Pass = 'SYNC PYNQ PASS:' },
    @{ Name = 'pynq-sync-mmcm-demo'; Script = 'run_pynq_sync_mmcm_demo_xsim.ps1'; Pass = 'MMCM PYNQ PASS:' },
    @{ Name = 'pynq-z2-nano-top'; Script = 'run_pynq_z2_nano_xsim.ps1'; Pass = 'PYNQ NANO PASS:' },
    @{ Name = 'controlled-pl-shell'; Script = 'run_pl_controlled_xsim.ps1'; Pass = 'CONTROLLED PL PASS:' }
)

foreach ($test in $tests) {
    $scriptPath = Join-Path $PSScriptRoot $test.Script
    Write-Host "=== STRICT PL TEST: $($test.Name) ==="
    try {
        # Merge success, error, warning, verbose, debug, and information
        # streams so pass markers printed with Write-Host are also audited.
        $lines = @(& $scriptPath -VivadoBin $VivadoBin *>&1 |
            ForEach-Object { $_.ToString() })
    }
    catch {
        throw "Strict test '$($test.Name)' raised an exception: $($_.Exception.Message)"
    }

    $output = $lines -join "`n"
    $exitCode = $LASTEXITCODE
    $output | Write-Host

    if ($exitCode -ne 0) {
        throw "Strict test '$($test.Name)' returned exit code $exitCode"
    }
    if ($output -notmatch [regex]::Escape($test.Pass)) {
        throw "Strict test '$($test.Name)' did not report its pass marker"
    }
    if ($output -match '(?im)^\s*(ERROR|FATAL|CRITICAL WARNING|WARNING:)') {
        throw "Strict test '$($test.Name)' emitted an error or warning"
    }
    if ($output -match '(?im)\b(segmentation fault|assertion failed|x/z detected|unknown value)\b') {
        throw "Strict test '$($test.Name)' reported an invalid simulation state"
    }

    Write-Host "PASS: $($test.Name)"
}

Write-Host 'STRICT PL REGRESSION PASS: all PL simulations completed without errors, warnings, or unknown-value failures'
