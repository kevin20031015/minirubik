# measure.ps1 - Stage 1 measurements of Ripes 
#
# Runs store_loop.s in Ripes CLI with STEP replaced (0 = same address,
# 4 = new address every store). Prints retired instructions (--iret),
# wall-clock seconds (including Ripes start-up), instructions per second,
# and the peak working set of the Ripes process (sampled every 50 ms).
# store_loop.s itself is not modified; a temporary copy goes to $env:TEMP.
#
#   Measure-Ripes 0 RV32_ISS | Tee-Object -Append results.txt
#   Measure-Ripes 4 RV32_ISS | Tee-Object -Append results.txt
#   Measure-Ripes 0 RV32_5S  | Tee-Object -Append results.txt
$ripes = "D:\claude\ripe\tools\Ripes\Ripes.exe"

function Measure-Ripes($step, $proc) {
  $src = [IO.File]::ReadAllText("$PWD\store_loop.s") -replace '\.equ STEP, \d+', ".equ STEP, $step"
  $tmp = "$env:TEMP\store_loop_tmp.s"; $out = "$env:TEMP\iret.txt"
  [IO.File]::WriteAllText($tmp, $src, (New-Object Text.UTF8Encoding $false))
  Remove-Item $out -ErrorAction SilentlyContinue
  $p = Start-Process $ripes -ArgumentList "--mode cli --src `"$tmp`" -t asm --proc $proc --iret --output `"$out`"" -PassThru -WindowStyle Hidden
  $peak = 0; $t = [Diagnostics.Stopwatch]::StartNew()
  while (-not $p.HasExited) { $p.Refresh(); if ($p.PeakWorkingSet64 -gt $peak) { $peak = $p.PeakWorkingSet64 }; Start-Sleep -Milliseconds 50 }
  $t.Stop(); $iret = [long](Get-Content $out)[1]; $sec = $t.Elapsed.TotalSeconds
  "STEP=$step  $proc  iret=$iret  seconds=$([math]::Round($sec,2))  rate=$([math]::Round($iret/$sec))  peak_bytes=$peak"
}
