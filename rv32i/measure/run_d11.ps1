# d11_states.txt lists the 2,644 states at distance 11 (found by a BFS over all
# 3,674,160 states with the same move tables as led.s / tables.s).
# For each state this script inlines it into solver.s, appends tables.s, runs the
# Ripes CLI with --iret, and records the retired-instruction count and the
# program's first output line. solver.s itself is not modified; the temporary
# copy goes to $env:TEMP.
#
# Usage (in the measure folder):
#   powershell -ExecutionPolicy Bypass -File run_d11.ps1 -limit 3     (quick test)
#   powershell -ExecutionPolicy Bypass -File run_d11.ps1              (all 2,644)
# Output: d11_iret.csv (state,iret,ok,output) and d11_summary.txt

param([string]$proc = "RV32_ISS", [int]$limit = 0)

# Path to the Ripes build used for every number in the note; change it on another machine.
$ripes = "D:\claude\ripe\tools\Ripes\Ripes.exe"
$dir = $PSScriptRoot
$enc = New-Object Text.UTF8Encoding $false
$src = [IO.File]::ReadAllText("$dir\..\solver.s")
$tables = [IO.File]::ReadAllText("$dir\..\tables.s")
$states = @(Get-Content "$dir\d11_states.txt" | Where-Object { $_ -match '^\d{14}$' })
if ($limit -gt 0) { $states = $states[0..($limit - 1)] }
$tmp = "$env:TEMP\d11_full.s"; $ir = "$env:TEMP\d11_iret.txt"
$csv = "$dir\d11_iret.csv"
[IO.File]::WriteAllText($csv, "state,iret,ok,output`r`n", $enc)

$i = 0; $bad = 0; $max = 0; $maxS = ""; $min = [long]::MaxValue; $minS = ""; $sum = 0
$t = [Diagnostics.Stopwatch]::StartNew()
foreach ($s in $states) {
    $i++
    $code = $src -replace 'input:\s*\.string\s*"[^"]*"', ('input:  .string "' + $s + '"')
    [IO.File]::WriteAllText($tmp, $code + "`n" + $tables, $enc)
    Remove-Item $ir -ErrorAction SilentlyContinue
    $out = & $ripes --mode cli --src $tmp -t asm --proc $proc --iret --output $ir | Out-String
    $line = ((($out -split "`n")[0]) -replace '\x1b\[[0-9;]*[A-Za-z]', '') -replace '[^ -~]', ''
    $n = -1
    if (Test-Path $ir) { $n = [long](Get-Content $ir)[1] }
    $ok = ($line -match '^11( \S+){11} PASS$') -and ($n -gt 0)
    if (-not $ok) { $bad++ }
    if ($n -gt $max) { $max = $n; $maxS = $s }
    if ($n -gt 0 -and $n -lt $min) { $min = $n; $minS = $s }
    if ($n -gt 0) { $sum += $n }
    [IO.File]::AppendAllText($csv, "$s,$n,$ok,$line`r`n", $enc)
    if ($i % 50 -eq 0 -or $i -eq $states.Count) {
        "{0,5} / {1}  max {2:N0} ({3})  not ok {4}  {5:N0} s" -f $i, $states.Count, $max, $maxS, $bad, $t.Elapsed.TotalSeconds
    }
}
$mean = [math]::Round($sum / [math]::Max(1, $states.Count - $bad))
$summary = @(
    "processor: $proc",
    "states run: $($states.Count)",
    "not 11 moves + PASS: $bad",
    ("max iret: {0} ({1})" -f $max, $maxS),
    ("min iret: {0} ({1})" -f $min, $minS),
    "mean iret: $mean",
    ("wall-clock: {0:N0} s" -f $t.Elapsed.TotalSeconds)
)
[IO.File]::WriteAllLines("$dir\d11_summary.txt", $summary, $enc)
$summary
