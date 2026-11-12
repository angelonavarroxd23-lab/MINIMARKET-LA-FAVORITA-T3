#!/usr/bin/env bash
# Levanta la base de datos y la interfaz web (Docker). Funciona en Linux, macOS y GitHub Codespaces.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -f .env ]; then
  pw="Lf$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 16)!aA1"
  printf 'MSSQL_SA_PASSWORD=%s\n' "$pw" > .env
  echo "Se generó .env con una contraseña aleatoria (no se sube a git)."
fi
docker compose up -d --build
echo "Esperando a que la aplicación responda..."
for i in $(seq 1 90); do
  if curl -fs http://localhost:3000/api/salud >/dev/null 2>&1; then echo "Listo: http://localhost:3000"; exit 0; fi
  sleep 3
done
echo "La aplicación no respondió a tiempo. Revisa: docker compose logs"; exit 1
