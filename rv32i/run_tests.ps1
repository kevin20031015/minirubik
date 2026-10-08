# The solver checks its own answer (check_loop replays the moves and prints
# PASS or FAIL). This script only feeds each input and compares the first
# output line with the expected move count.
#
# Usage (in the rv32i folder):
#   powershell -ExecutionPolicy Bypass -File run_tests.ps1                  (RV32_ISS)
#   powershell -ExecutionPolicy Bypass -File run_tests.ps1 -proc RV32_5S    (5-stage pipeline, gate T7)

param([string]$proc = "RV32_ISS")

$ripes = "D:\claude\ripe\tools\Ripes\Ripes.exe"
$dir = $PSScriptRoot

$tests = @(
    @{ name = "solved";         input = "12345671111111"; expect = '^0 PASS$' },
    @{ name = "short scramble"; input = "25314672313211"; expect = '^1 \S+ PASS$' },
    @{ name = "distance 11";    input = "21345671111111"; expect = '^11( \S+){11} PASS$' },
    @{ name = "worst case";     input = "54721631111111"; expect = '^11( \S+){11} PASS$' },
    @{ name = "repeated digit"; input = "11111111111111"; expect = '^ INVALID$' },
    @{ name = "bad twist sum";  input = "12345671111112"; expect = '^ INVALID$' }
)

$src = [IO.File]::ReadAllText("$dir\solver.s")
$tables = [IO.File]::ReadAllText("$dir\tables.s")
$failed = 0
foreach ($t in $tests) {
    $s = $src -replace 'input:\s*\.string\s*"[^"]*"', ('input:  .string "' + $t.input + '"')
    [IO.File]::WriteAllText("$dir\test_full.s", $s + "`n" + $tables, (New-Object Text.UTF8Encoding $false))
    $out = & $ripes --mode cli --src "$dir\test_full.s" -t asm --proc $proc | Out-String
    $raw = ($out -split "`n")[0]
    $line = $raw -replace '\x1b\[[0-9;]*[A-Za-z]', ''   # drop terminal color codes
    $line = $line -replace '[^ -~]', ''               # keep printable ASCII only (drops CR, NUL, BOM)
    if ($line -match $t.expect) { $mark = "ok   " } else { $mark = "WRONG"; $failed++ }
    "{0}  {1,-15} {2}  =>  {3}" -f $mark, $t.name, $t.input, $line
    if ($mark -eq "WRONG") {
        "       debug: char codes = " + (($raw.ToCharArray() | ForEach-Object { [int]$_ }) -join ",")
        "       debug: expect = " + $t.expect
    }
}
if ($failed -eq 0) { "all $($tests.Count) tests passed on $proc" } else { "$failed test(s) failed"; exit 1 }
