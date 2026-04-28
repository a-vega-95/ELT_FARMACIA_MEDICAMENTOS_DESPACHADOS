# =============================================================================
# EJECUTOR PRINCIPAL - PIPELINE TARGETS
# =============================================================================

options(repos = c(CRAN = "https://cran.rstudio.com/"))

if (!require("targets", quietly = TRUE)) install.packages("targets")
if (!require("tarchetypes", quietly = TRUE)) install.packages("tarchetypes")

library(targets)
library(here)

# Cargar e inicializar estructura de carpetas
source(here::here("R", "99_bootstrapping.R"))
inicializar_proyecto()

cat("═══════════════════════════════════════════════════════════════\n")
cat("  EJECUTANDO PIPELINE (TARGETS)\n")
cat("═══════════════════════════════════════════════════════════════\n")

# Ejecutar el pipeline
tar_make()

if (file.exists("datos_salida/recetas_despachadas_consolidado.parquet")) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("  PROCESO COMPLETADO\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat(sprintf("Salida: %s\n", here::here("datos_salida/recetas_despachadas_consolidado.parquet")))
}

