<#
 collect_evidence.ps1 - Reconstruye la base y guarda en evidencias/ la salida REAL de cada paso:
   00_build_log.txt, 01_inventario.txt, 02_ejercicios.txt, 03_test_views.txt, 04_test_queries.txt,
   05_test_procedures.txt, 06_test_integrity.txt, 07_controles_integridad.txt, 99_resumen.txt
 Uso: .\scripts\collect_evidence.ps1 [-Server localhost] [-User sa -Password ...]
#>
param([string]$Server = "localhost", [string]$User = "", [string]$Password = "")
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
$ev = Join-Path $root "evidencias"; New-Item -ItemType Directory -Force $ev | Out-Null
[string[]]$auth = if ($User) { @("-U", $User, "-P", $Password) } else { @("-E") }
$tab = "`t"
function Run($file, $outFile, [switch]$Tabs) {
  [string[]]$sep = if ($Tabs) { @("-s", $tab) } else { @() }
  & sqlcmd -S $Server @auth -C -b -I -f 65001 -W @sep -i (Join-Path $root $file) -o (Join-Path $ev $outFile)
  return $LASTEXITCODE
}
$log = Join-Path $ev "00_build_log.txt"; "" | Out-File $log -Encoding utf8
$status = @{}
foreach ($f in "01_create_database","02_create_tables","03_insert_data","04_views","05_subqueries","06_multitable_queries",
                "07_procedures_insert","08_procedures_update","09_procedures_delete","10_procedures_select") {
  $o = & sqlcmd -S $Server @auth -C -b -I -f 65001 -i (Join-Path $root "database\$f.sql") 2>&1
  $code = $LASTEXITCODE; $status[$f] = $code
  "=== $f.sql  (codigo de salida: $code)" | Out-File $log -Append -Encoding utf8
  ($o | Select-Object -First 400) | Out-File $log -Append -Encoding utf8
}
$status["inventario"]   = Run "tests\evidence_inventory.sql" "01_inventario.txt" -Tabs
$status["ejercicios"]   = Run "tests\evidence_run.sql"       "02_ejercicios.txt" -Tabs
$status["test_views"]   = Run "tests\test_views.sql"         "03_test_views.txt" -Tabs
$status["test_queries"] = Run "tests\test_queries.sql"       "04_test_queries.txt" -Tabs
$status["test_procedures"] = Run "tests\test_procedures.sql" "05_test_procedures.txt" -Tabs
$status["test_integrity"]  = Run "tests\test_integrity.sql"  "06_test_integrity.txt" -Tabs
$status["integridad"]   = Run "database\11_integrity_tests.sql" "07_controles_integridad.txt" -Tabs
$status.GetEnumerator() | Sort-Object Name | ForEach-Object { "{0,-28} codigo de salida {1}" -f $_.Name, $_.Value } | Out-File (Join-Path $ev "99_resumen.txt") -Encoding utf8
Get-Content (Join-Path $ev "99_resumen.txt")
