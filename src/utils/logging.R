library(digest)
library(stringr)

#' Genera metadatos del sistema para trazabilidad
get_sys_metadata <- function() {
  list(
    usuario = Sys.getenv("USERNAME"),
    pc_name = Sys.getenv("COMPUTERNAME"),
    os = Sys.info()[["sysname"]],
    r_version = R.version.string,
    ram_peak_mb = round(sum(gc()[, 6]), 2)
  )
}

#' Genera el reporte profesional final en un único archivo log
escribir_reporte_auditoria <- function(id_ejecucion, metricas_capas, path_final, estado = "SUCCESS") {
  meta <- get_sys_metadata()
  timestamp_fin <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  
  log_path <- here::here("logs", sprintf("audit_%s_%s.log", format(Sys.time(), "%Y%m%d_%H%M"), str_sub(id_ejecucion, 1, 8)))
  if (!dir.exists(dirname(log_path))) dir.create(dirname(log_path), recursive = TRUE)
  
  lineas <- c(
    "═══════════════════════════════════════════════════════════════",
    sprintf("  AUDITORIA DE EJECUCIÓN - %s", id_ejecucion),
    "═══════════════════════════════════════════════════════════════",
    sprintf("- Proceso: etl_recetas_despachadas_2.0v"),
    sprintf("- Usuario: %s | Host: %s | OS: %s", meta$usuario, meta$pc_name, meta$os),
    sprintf("- Estado Final: %s", estado),
    sprintf("- Fin Proceso: %s", timestamp_fin),
    "",
    "1. METRICAS DE VOLUMEN",
    sprintf("- Filas entrada (Bronze): %d", metricas_capas$bronze$filas),
    sprintf("- Filas normalizadas (Silver): %d", metricas_capas$silver$filas),
    sprintf("- Filas finales (Gold): %d", metricas_capas$gold$filas),
    sprintf("- Delta final vs entrada: %d", metricas_capas$gold$filas - metricas_capas$bronze$filas),
    "",
    "2. CALIDAD DE DATOS (DOMINIO)",
    sprintf("- Nulos en homologacion iGLOBAL: %d", metricas_capas$gold$nulos_iglobal),
    sprintf("- ALERTAS TOTALES DETECTADAS: %d", metricas_capas$gold$alertas$totales),
    sprintf("    [!] Inconsistencias de Fecha: %d", metricas_capas$gold$alertas$por_fecha),
    sprintf("    [!] Dosis fuera de rango (>1000): %d", metricas_capas$gold$alertas$por_dosis),
    sprintf("- Hash Integridad Final: %s", metricas_capas$gold$hash_final),
    "",
    "3. RENDIMIENTO Y RECURSOS",
    sprintf("- Memoria RAM Pico: %s MB", meta$ram_peak_mb),
    "4. PRODUCTOS GENERADOS",
    sprintf("- Capa Gold (Final): %s", basename(path_final)),
    if(!is.null(metricas_capas$quarentine_path)) sprintf("- Cuarentena (XLSX): %s", basename(metricas_capas$quarentine_path)) else "- Cuarentena: Sin registros anómalos",
    "═══════════════════════════════════════════════════════════════"
  )
  
  writeLines(lineas, log_path)
  cat(sprintf("\n[AUDIT] Reporte consolidado generado en: %s\n", basename(log_path)))
  
  return(log_path)
}
