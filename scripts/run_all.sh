#!/usr/bin/env bash
# run_all.sh - Construye la base MinimarketLaFavorita y ejecuta las pruebas (Linux/macOS/CI).
# Uso:
#   SA_PASSWORD='...' bash scripts/run_all.sh                       # SQL Server en localhost, usuario sa
#   SQL_SERVER=host,1433 SQL_USER=usuario SA_PASSWORD='...' bash scripts/run_all.sh
# La contraseña se recibe por variable de entorno (nunca se guarda en el repositorio).
set -euo pipefail
cd "$(dirname "$0")/.."

SQL_SERVER="${SQL_SERVER:-localhost}"
SQL_USER="${SQL_USER:-sa}"
: "${SA_PASSWORD:?Defina la variable SA_PASSWORD con la contraseña de SQL Server}"
SQLCMD="${SQLCMD:-$(ls /opt/mssql-tools*/bin/sqlcmd 2>/dev/null | tail -1 || true)}"
SQLCMD="${SQLCMD:-$(command -v sqlcmd)}"
export SQLCMDPASSWORD="$SA_PASSWORD"          # sqlcmd lee la contraseña de esta variable

mkdir -p evidencias
: > evidencias/ci_log.txt
run() {
  echo ">> $1" | tee -a evidencias/ci_log.txt
  # -b: abortar y devolver código de error | -I: QUOTED_IDENTIFIER ON | -C: confiar en el certificado | -f 65001: UTF-8
  "$SQLCMD" -S "$SQL_SERVER" -U "$SQL_USER" -C -b -I -f 65001 -i "$1" 2>&1 | tee -a evidencias/ci_log.txt
}

for f in 01_create_database 02_create_tables 03_insert_data 04_views 05_subqueries 06_multitable_queries \
         07_procedures_insert 08_procedures_update 09_procedures_delete 10_procedures_select 11_integrity_tests; do
  run "database/$f.sql"
done
if [ "${SKIP_TESTS:-0}" != "1" ]; then
  for t in test_views test_queries test_procedures test_integrity; do
    run "tests/$t.sql"
  done
fi
echo "TODO CORRECTO: base creada y pruebas aprobadas." | tee -a evidencias/ci_log.txt
