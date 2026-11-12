<#
 start_web.ps1 - Levanta SQL Server (Docker) + la interfaz web en http://localhost:3000
 Requiere Docker Desktop. Genera .env con una contraseña aleatoria la primera vez (no se versiona).
 Parar:  docker compose down      Parar y borrar datos:  docker compose down -v
#>
$ErrorActionPreference = "Continue"
Set-Location (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path .env)) {
  $pw = "Lf" + [guid]::NewGuid().ToString("N").Substring(0,16) + "!aA1"
  Set-Content -Path .env -Value "MSSQL_SA_PASSWORD=$pw" -Encoding ASCII
  Write-Host "Se genero .env con una contrasena aleatoria (no se sube a git)."
}
docker compose up -d --build
if ($LASTEXITCODE -ne 0) { throw "docker compose fallo" }
Write-Host "Esperando a que la aplicacion responda..."
for ($i = 1; $i -le 90; $i++) {
  try { $r = Invoke-WebRequest -UseBasicParsing http://localhost:3000/api/salud -TimeoutSec 5; if ($r.StatusCode -eq 200) { Write-Host "Listo: http://localhost:3000" -ForegroundColor Green; Start-Process "http://localhost:3000"; return } } catch { }
  Start-Sleep -Seconds 3
}
throw "La aplicacion no respondio a tiempo. Revisa: docker compose logs"
