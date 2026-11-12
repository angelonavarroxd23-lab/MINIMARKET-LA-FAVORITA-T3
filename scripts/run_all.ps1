<#
 run_all.ps1 - Construye la base MinimarketLaFavorita y ejecuta las pruebas en SQL Server.
 Uso (autenticación de Windows):   .\scripts\run_all.ps1
 Uso (autenticación SQL):          .\scripts\run_all.ps1 -User sa -Password $env:SA_PASSWORD
 Parametros: -Server (por defecto localhost) -SkipTests
 La contraseña nunca se escribe en el código: se recibe por parámetro o variable de entorno.
#>
param(
  [string]$Server   = "localhost",
  [string]$User     = "",
  [string]$Password = "",
  [switch]$SkipTests
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
[string[]]$auth = if ($User) { @("-U", $User, "-P", $Password) } else { @("-E") }

function Invoke-Sql($file) {
  Write-Host ">> $file" -ForegroundColor Cyan
  # -b: abortar con error | -I: QUOTED_IDENTIFIER ON (columna calculada) | -f 65001: UTF-8
  & sqlcmd -S $Server @auth -C -b -I -f 65001 -i (Join-Path $root $file)
  if ($LASTEXITCODE -ne 0) { throw "Fallo la ejecucion de $file (codigo $LASTEXITCODE)" }
}

$build = "01_create_database","02_create_tables","03_insert_data","04_views","05_subqueries",
         "06_multitable_queries","07_procedures_insert","08_procedures_update",
         "09_procedures_delete","10_procedures_select","11_integrity_tests"
foreach ($f in $build) { Invoke-Sql "database\$f.sql" }

if (-not $SkipTests) {
  foreach ($t in "test_views","test_queries","test_procedures","test_integrity") { Invoke-Sql "tests\$t.sql" }
}
Write-Host "TODO CORRECTO: base creada y pruebas aprobadas." -ForegroundColor Green
