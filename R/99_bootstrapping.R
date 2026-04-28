#' Inicializa la estructura de directorios del proyecto
#' @description Crea todas las carpetas necesarias para el funcionamiento del pipeline si no existen.
#' @return NULL
inicializar_proyecto <- function() {
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("  INICIALIZANDO ENTORNO DE TRABAJO\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  
  # Definición de directorios requeridos
  directorios <- c(
    here::here("datos", "entrada"),
    here::here("datos", "bronze"),
    here::here("datos", "silver"),
    here::here("datos", "gold"),
    here::here("datos", "cuarentena"),
    here::here("schemas"),
    here::here("logs"),
    here::here("diccionario_homologacion"),
    here::here("tests", "testthat")
  )
  
  creados <- 0
  for (dir in directorios) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE)
      cat(sprintf("   [+] Creado: %s\n", basename(dir)))
      creados <- creados + 1
    }
  }
  
  if (creados == 0) {
    cat("   [OK] Estructura de directorios verificada (ya existe).\n")
  } else {
    cat(sprintf("   [OK] %d carpetas creadas con éxito.\n", creados))
  }
  
  cat("═══════════════════════════════════════════════════════════════\n\n")
}
