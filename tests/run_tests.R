library(testthat)
library(here)

cat("═══════════════════════════════════════════════════════════════\n")
cat("  EJECUTANDO PRUEBAS UNITARIAS E INTEGRACIÓN\n")
cat("═══════════════════════════════════════════════════════════════\n")

# Ejecutar todos los archivos de prueba en tests/testthat
test_results <- test_dir(here("tests", "testthat"), stop_on_failure = FALSE)

cat("\n═══════════════════════════════════════════════════════════════\n")
cat("  RESUMEN DE PRUEBAS\n")
cat("═══════════════════════════════════════════════════════════════\n")
print(test_results)
cat("═══════════════════════════════════════════════════════════════\n")
