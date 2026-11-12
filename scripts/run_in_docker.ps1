<#
 run_in_docker.ps1 - Ejecuta el proyecto completo en un contenedor oficial de SQL Server 2022 (mismos pasos que GitHub Actions).
 Requiere Docker Desktop. No toca ninguna instancia de SQL Server instalada: usa un contenedor desechable con
 contraseña aleatoria que se elimina al terminar.
 Uso:  powershell -ExecutionPolicy Bypass -File .\scripts\run_in_docker.ps1
#>
$ErrorActionPreference = "Continue"   # los errores de docker/sqlcmd se controlan con $LASTEXITCODE
$root = Split-Path -Parent $PSScriptRoot
$name = "sqlserver-t3-ci"
$pw = "Ci" + [guid]::NewGuid().ToString("N").Substring(0,16) + "!aA1"      # contraseña efímera
docker rm -f $name 2>$null | Out-Null
try {
  docker run -d --name $name -e ACCEPT_EULA=Y -e "MSSQL_SA_PASSWORD=$pw" -e MSSQL_PID=Developer mcr.microsoft.com/mssql/server:2022-latest | Out-Null
  $sqlcmd = (docker exec $name bash -c 'ls /opt/mssql-tools*/bin/sqlcmd | tail -1').Trim()
  $ready = $false
  for ($i = 1; $i -le 60; $i++) {
    docker exec -e "SQLCMDPASSWORD=$pw" $name $sqlcmd -S localhost -U sa -C -Q "SELECT 1" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "SQL Server listo tras $i intento(s)"; $ready = $true; break }
    Start-Sleep -Seconds 3
  }
  if (-not $ready) { throw "SQL Server no arranco a tiempo" }
  docker cp "$root\." "${name}:/work"
  docker exec -u 0 -e "SA_PASSWORD=$pw" -e "SQLCMD=$sqlcmd" -w /work $name bash -c "sed -i 's/\r$//' scripts/run_all.sh && bash scripts/run_all.sh"
  if ($LASTEXITCODE -ne 0) { throw "Fallo la ejecucion en el contenedor" }
  $ver = docker exec -e "SQLCMDPASSWORD=$pw" $name $sqlcmd -S localhost -U sa -C -h -1 -W -Q "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(30)) + ' / ' + CAST(SERVERPROPERTY('Edition') AS VARCHAR(60))"
  Write-Host "Motor del contenedor: $ver" -ForegroundColor Green
} finally {
  docker rm -f $name 2>$null | Out-Null
}
