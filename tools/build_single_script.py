"""Concatena database/01..11 en PROYECTO_T3_LA_FAVORITA.sql (mismo orden de ejecución que run_all)."""
import glob, os
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
files = sorted(glob.glob(os.path.join(root, "database", "[0-9][0-9]_*.sql")))
out = ["/* ============================================================================",
       " PROYECTO T3 - Minimarket «La Favorita» - Script único (scripts 01 a 11 de database/)",
       " Ejecutar con sqlcmd -b -I (QUOTED_IDENTIFIER ON; la columna calculada persistida lo exige) o en SSMS.",
       " Crea la base MinimarketLaFavorita (solo recrea una base que lleve la marca del proyecto).",
       " ============================================================================ */", "GO", ""]
for f in files:
    out += [f"/* ##### {os.path.basename(f)} ##### */", open(f, encoding="utf-8-sig").read().rstrip(), "GO", ""]
open(os.path.join(root, "PROYECTO_T3_LA_FAVORITA.sql"), "w", encoding="utf-8-sig", newline="\r\n").write("\n".join(out))
print(len(files), "archivos")
