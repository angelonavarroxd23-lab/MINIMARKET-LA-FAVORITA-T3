<#
 publicar_github.ps1 - Publica este proyecto como repositorio MINIMARKET-LA-FAVORITA-T3 en tu cuenta de GitHub.
 Requisitos: git y la CLI de GitHub (gh) con sesion iniciada (gh auth login). Las credenciales las gestiona gh/git:
 este script no pide ni guarda contrasenas ni tokens.
 Uso:  powershell -ExecutionPolicy Bypass -File .\scripts\publicar_github.ps1 [-Visibilidad public|private]
#>
param([ValidateSet("public","private")][string]$Visibilidad = "public")
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Instala Git: https://git-scm.com/download/win" }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "Instala la CLI de GitHub (https://cli.github.com) y ejecuta: gh auth login" }
gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) { throw "No hay sesion de GitHub. Ejecuta: gh auth login" }

# El flujo de Actions debe estar en .github/workflows
New-Item -ItemType Directory -Force .github\workflows | Out-Null
if (Test-Path ci\sqlserver-tests.yml) { Copy-Item ci\sqlserver-tests.yml .github\workflows\sqlserver-tests.yml -Force }

if (-not (Test-Path .git)) { git init -b main | Out-Null }
git add -A
if (-not (git config user.email)) { throw "Configura tu identidad de git: git config --global user.name ""Tu nombre""; git config --global user.email ""tu_correo""" }
git commit -m "Proyecto T3: vistas, subconsultas, multitabla y procedimientos (SQL Server)" 2>$null | Out-Null
gh repo create MINIMARKET-LA-FAVORITA-T3 --$Visibilidad --source . --remote origin --push
if ($LASTEXITCODE -ne 0) { throw "No se pudo crear/subir el repositorio (¿ya existe?)." }
Write-Host "Repositorio publicado:" -ForegroundColor Green
gh repo view --json url -q .url
Write-Host "Revisa la pestaña Actions del repositorio: el flujo se ejecuta con el primer push." -ForegroundColor Yellow
